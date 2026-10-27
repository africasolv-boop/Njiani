-- Telling a driver's feed that something changed. Component C9.
--
-- THE PROBLEM THIS SOLVES, AND WHY THE OBVIOUS ANSWER IS WRONG
--
-- The obvious way to make a feed live is to subscribe to `ride_requests` and
-- let Postgres Changes stream the rows in. That cannot work here, and it
-- should not: realtime respects RLS, and a driver holds no read policy on
-- that table at all (ARCHITECTURE §8). They read matches ONLY through
-- `match_requests_for_session()`, scoped to their own session, so that a
-- driver can never enumerate who is waiting where and for how much.
--
-- So the signal and the data are split. This trigger broadcasts a NUDGE
-- carrying no passenger information -- a route, a vehicle type, a timestamp
-- -- and the client answers it by re-running the matching function, which
-- applies the same scoping it always did. The live part is a doorbell, not a
-- window.
--
-- WHAT THE NUDGE DOES NOT CARRY: no request id, no pickup, no destination,
-- no price, no passenger. A listener learns that there is demand for a bajaj
-- somewhere on the Ubungo-Kimara corridor, which is also what they would
-- learn by standing at the stage and looking.

set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- The topic a feed listens on.
--
-- One per route and vehicle type, which is exactly the granularity a session
-- has: a driver heading west in a bajaj has no use for a nudge about
-- eastbound boda demand, and waking their phone for it costs them battery.
--
-- Shared by the trigger and the client, so the two cannot disagree about the
-- name -- a mismatch there is a feed that is silently never live.
-- ---------------------------------------------------------------------------
create or replace function public.route_feed_topic(
  p_route_id     uuid,
  p_vehicle_type public.vehicle_type
)
returns text
language sql
immutable
as $$
  select 'feed:' || p_route_id::text || ':' || p_vehicle_type::text;
$$;

comment on function public.route_feed_topic(uuid, public.vehicle_type) is
  'C9. The realtime topic a driver feed listens on. Must match the client.';

-- ---------------------------------------------------------------------------
-- The trigger.
--
-- BEST EFFORT, DELIBERATELY. The whole body is wrapped so that no failure
-- here can stop a passenger's request being written. Getting that backwards
-- would mean a broadcast outage, a renamed `realtime.send`, or a missing
-- schema taking out the thing the app exists to do -- to save a driver's feed
-- a few seconds of staleness. The client polls as well for exactly this
-- reason, so a dropped nudge costs latency and nothing else.
-- ---------------------------------------------------------------------------
create or replace function public.notify_route_of_request()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_row public.ride_requests := coalesce(new, old);
begin
  begin
    perform realtime.send(
      jsonb_build_object(
        'route_id',     v_row.route_id,
        'vehicle_type', v_row.vehicle_type,
        'at',           now()
      ),
      'feed_changed',
      public.route_feed_topic(v_row.route_id, v_row.vehicle_type),
      -- Private: Realtime checks `realtime.messages` RLS before delivering,
      -- and the policy below lets only a driver who is online on that route
      -- subscribe. The payload is harmless, but "deny unless a policy says
      -- otherwise" is how every other table in this schema works and there
      -- is no reason for this one to be the exception.
      true
    );
  exception when others then
    -- Swallowed on purpose. See the note above.
    null;
  end;

  return coalesce(new, old);
end;
$$;

-- Fires on anything that changes what a feed should show: a new request, and
-- a request leaving `open` because somebody claimed, cancelled or expired it
-- -- which is how a card disappears from every other driver's feed.
drop trigger if exists ride_requests_feed_nudge on public.ride_requests;
create trigger ride_requests_feed_nudge
  after insert or update of status or delete on public.ride_requests
  for each row execute function public.notify_route_of_request();

-- ---------------------------------------------------------------------------
-- Who may subscribe.
--
-- `realtime.messages` is Supabase's own table and already has RLS enabled;
-- without a policy, a private topic delivers to nobody. This one says: you
-- may listen to a route's feed topic while you are actually online on that
-- route, in that vehicle. It expires with the session, which is the same
-- lifetime the feed itself has.
--
-- Guarded, because `realtime.messages` does not exist on a plain Postgres
-- and this file has to apply there too -- the local harness stubs the
-- `realtime` schema, but a stub that invents a policy API Supabase does not
-- have would be worse than no stub.
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('realtime.messages') is null then
    raise notice 'realtime.messages not present; skipping the subscribe policy';
    return;
  end if;

  drop policy if exists feed_listen_own_route on realtime.messages;

  create policy feed_listen_own_route on realtime.messages
    for select to authenticated
    using (
      exists (
        select 1
        from public.driver_sessions ds
        where ds.driver_id = auth.uid()
          and ds.status = 'online'
          and realtime.messages.topic
                = public.route_feed_topic(ds.route_id, ds.vehicle_type)
      )
    );
end
$$;

-- ---------------------------------------------------------------------------
-- The feed's header, resolved in one call.
--
-- The route board needs two place names: where the driver is, and where they
-- said they are heading. The session stores a destination id and a position,
-- so both need a lookup -- and doing them client-side would mean two more
-- round trips per refresh on a connection that costs the driver money, or
-- worse, guessing.
--
-- "Where the driver is" is the nearest stage to `last_pos`, recomputed every
-- read. A board that still says Ubungo when the driver has reached Kibo is
-- worse than one that says nothing: it is the app claiming to know where they
-- are and being wrong.
-- ---------------------------------------------------------------------------
create or replace function public.current_driver_session()
returns table (
  id             uuid,
  driver_id      uuid,
  route_id       uuid,
  dest_stage_id  uuid,
  vehicle_type   public.vehicle_type,
  seats_total    smallint,
  seats_free     smallint,
  status         text,
  went_online_at timestamptz,
  dest_name      text,
  dest_name_sw   text,
  from_name      text,
  from_name_sw   text
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select
    ds.id,
    ds.driver_id,
    ds.route_id,
    ds.dest_stage_id,
    ds.vehicle_type,
    ds.seats_total,
    ds.seats_free,
    ds.status,
    ds.went_online_at,
    dest.name,
    dest.name_sw,
    here.name,
    here.name_sw
  from public.driver_sessions ds
  join public.stages dest on dest.id = ds.dest_stage_id
  -- Left, not inner: a driver who has just gone online with no fix still has
  -- a session, and a header missing one name is better than no session at
  -- all.
  left join lateral (
    select ns.name, ns.name_sw
    from public.nearest_stage(ds.last_pos) ns
    where ds.last_pos is not null
  ) here on true
  where ds.driver_id = auth.uid()
    and ds.status = 'online';
$$;

comment on function public.current_driver_session() is
  'C9. The driver''s open session with its place names resolved.';

revoke execute on function public.current_driver_session() from public;
grant execute on function public.current_driver_session() to authenticated;


-- ---------------------------------------------------------------------------
-- A driver does not appear in their own feed.
--
-- `match_requests_for_session` had no clause excluding the caller's own
-- requests, so a driver who had also asked for a ride -- a driver is a
-- passenger on their days off, and the request outlives the mood -- would be
-- offered themselves. Claiming it would write a `trip_seats` row whose driver
-- and passenger are the same person, which is not a trip.
--
-- Added as a `where` on the existing function rather than as a constraint:
-- the row is not invalid, it is just not something to show this driver.
-- ---------------------------------------------------------------------------
create or replace function public.match_requests_for_session(p_session_id uuid)
returns table (
  request_id      uuid,
  pickup_stage    text,
  pickup_stage_sw text,
  dest_stage      text,
  dest_stage_sw   text,
  offer_price     integer,
  meters_ahead    integer,
  created_at      timestamptz
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  with session as (
    select
      ds.vehicle_type,
      ds.seats_free,
      ds.driver_id,
      ds.route_id,
      r.geom::geometry as route_geom,
      r.geom           as route_geog,
      r.corridor_m,
      coalesce(
        st_linelocatepoint(r.geom::geometry, ds.last_pos::geometry),
        0
      ) as driver_t,
      st_linelocatepoint(r.geom::geometry, dest.geom::geometry) as dest_t,
      st_length(r.geom) as route_m
    from public.driver_sessions ds
    join public.routes r    on r.id = ds.route_id
    join public.stages dest on dest.id = ds.dest_stage_id
    where ds.id = p_session_id
      and ds.status = 'online'
      and ds.driver_id = auth.uid()
  ),
  candidate as (
    select
      rr.id,
      rr.offer_price,
      rr.created_at,
      ps.name    as pickup_name,
      ps.name_sw as pickup_name_sw,
      de.name    as dest_name,
      de.name_sw as dest_name_sw,
      s.driver_t,
      s.dest_t,
      s.route_m,
      s.corridor_m,
      s.route_geog,
      rr.pickup,
      st_linelocatepoint(s.route_geom, rr.pickup::geometry) as pickup_t,
      st_linelocatepoint(s.route_geom, de.geom::geometry)   as drop_t
    from session s
    join public.ride_requests rr on rr.status = 'open'
    left join public.stages ps on ps.id = rr.pickup_stage_id
    join public.stages de on de.id = rr.dest_stage_id
    where rr.vehicle_type = s.vehicle_type
      and rr.expires_at   > now()
      and rr.route_id     = s.route_id
      and s.seats_free    > 0
      -- Not your own. See the note above this function.
      and rr.passenger_id <> s.driver_id
  )
  select
    c.id,
    coalesce(c.pickup_name, 'On the road'),
    coalesce(c.pickup_name_sw, 'Barabarani'),
    c.dest_name,
    c.dest_name_sw,
    c.offer_price,
    greatest(0, round((c.pickup_t - c.driver_t) * c.route_m))::integer,
    c.created_at
  from candidate c
  where st_dwithin(c.pickup, c.route_geog, c.corridor_m)
    and c.pickup_t > c.driver_t
    and c.pickup_t <= c.dest_t
    and c.drop_t   <= c.dest_t
  order by c.pickup_t asc;
$$;
