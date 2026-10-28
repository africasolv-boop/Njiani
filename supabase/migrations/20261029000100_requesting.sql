-- Asking for a seat. Component C8.
--
-- The passenger's whole job: where they are going, in what, for how much. The
-- price is theirs to set -- a band is a hint and never a rule, and an offer
-- below it still sends (ARCHITECTURE §7). What the client does NOT get to
-- decide is anything that would make the request unmatchable:
--
--   * which route the pair of stages is on,
--   * where the pickup is on the earth,
--   * whether the destination is actually further along than the pickup.
--
-- Each of those is resolved or checked here. A request that describes a trip
-- backwards is written exactly as asked and then never appears in any feed,
-- which is the worst kind of bug: everything succeeded and nothing happened.

set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- 1. The price band
--
-- What drivers on this pair usually accept. Hand-seeded at launch, later
-- derived from accepted trips.
--
-- Returns no row when the pair has never been priced, which the screen says
-- out loud rather than inventing a number: a made-up band is worse than none,
-- because a passenger would anchor to it.
--
-- `mid` is rounded to the nearest 100, for the middle chip. Nobody offers
-- TSh 1,137.
-- ---------------------------------------------------------------------------
create or replace function public.price_band(
  p_from_stage uuid,
  p_to_stage   uuid,
  p_vehicle    public.vehicle_type
)
returns table (low integer, high integer, mid integer)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select
    b.low,
    b.high,
    (round((b.low + b.high) / 2.0 / 100) * 100)::integer
  from public.price_bands b
  where b.from_stage_id = p_from_stage
    and b.to_stage_id   = p_to_stage
    and b.vehicle_type  = p_vehicle;
$$;

-- ---------------------------------------------------------------------------
-- 2. Making the request
-- ---------------------------------------------------------------------------
create or replace function public.create_ride_request(
  p_pickup_stage_id uuid,
  p_dest_stage_id   uuid,
  p_vehicle_type    public.vehicle_type,
  p_offer_price     integer
)
returns public.ride_requests
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_pickup  public.stages;
  v_dest    public.stages;
  v_request public.ride_requests;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;

  if p_offer_price is null or p_offer_price <= 0 then
    raise exception 'a price is required' using errcode = '22023';
  end if;

  select * into v_pickup from public.stages where id = p_pickup_stage_id and active;
  select * into v_dest   from public.stages where id = p_dest_stage_id   and active;

  if v_pickup.id is null or v_dest.id is null then
    raise exception 'that stage is not on an active route' using errcode = '22023';
  end if;

  -- Both ends on the same road, and the destination genuinely further along
  -- it. Without this the row is written exactly as asked and then matches
  -- nothing, forever: the driver feed only ever looks ahead.
  if v_pickup.route_id <> v_dest.route_id then
    raise exception 'those two stages are on different routes'
      using errcode = '22023';
  end if;

  if v_dest.seq <= v_pickup.seq then
    raise exception 'the destination has to be further along the road than the pickup'
      using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.routes where id = v_pickup.route_id and active
  ) then
    raise exception 'that route is not active' using errcode = '22023';
  end if;

  -- One open request per passenger. The unique index already says so; this
  -- says it in a sentence, because the screen has to offer to cancel the
  -- other one and needs to know that is what happened.
  if exists (
    select 1 from public.ride_requests
    where passenger_id = auth.uid() and status = 'open'
  ) then
    raise exception 'you already have a request waiting'
      using errcode = '23505';
  end if;

  insert into public.ride_requests
    (passenger_id, route_id, pickup, pickup_stage_id, dest_stage_id,
     vehicle_type, offer_price)
  values (
    auth.uid(),
    v_pickup.route_id,
    -- From the stage, not from the client. A pickup point that drifts off
    -- the corridor is a request no feed will show.
    v_pickup.geom,
    v_pickup.id,
    v_dest.id,
    p_vehicle_type,
    p_offer_price
  )
  returning * into v_request;

  return v_request;
end;
$$;

comment on function public.create_ride_request(uuid, uuid, public.vehicle_type, integer) is
  'C8. The passenger asks for a seat. Route and pickup point are resolved '
  'here; the price is the passenger''s.';

-- ---------------------------------------------------------------------------
-- 3. Withdrawing it
--
-- Cancelled, never deleted. An unmatched request carries its offer, its
-- destination and its time of day, which is the fastest route to real price
-- bands -- and a withdrawn one says something an expired one does not
-- (ARCHITECTURE §7).
-- ---------------------------------------------------------------------------
create or replace function public.cancel_ride_request()
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_cancelled integer;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;

  update public.ride_requests
     set status = 'cancelled', cancelled_at = now()
   where passenger_id = auth.uid() and status = 'open';

  get diagnostics v_cancelled = row_count;
  return v_cancelled;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. The request the passenger is waiting on
--
-- With its place names resolved, for the same reason `current_driver_session`
-- resolves them: the alternative is two more round trips on a connection the
-- passenger is paying for.
-- ---------------------------------------------------------------------------
create or replace function public.current_ride_request()
returns table (
  id              uuid,
  route_id        uuid,
  pickup_stage_id uuid,
  dest_stage_id   uuid,
  vehicle_type    public.vehicle_type,
  offer_price     integer,
  status          public.request_status,
  created_at      timestamptz,
  expires_at      timestamptz,
  pickup_name     text,
  pickup_name_sw  text,
  dest_name       text,
  dest_name_sw    text
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select
    rr.id,
    rr.route_id,
    rr.pickup_stage_id,
    rr.dest_stage_id,
    rr.vehicle_type,
    rr.offer_price,
    rr.status,
    rr.created_at,
    rr.expires_at,
    ps.name,
    ps.name_sw,
    de.name,
    de.name_sw
  from public.ride_requests rr
  left join public.stages ps on ps.id = rr.pickup_stage_id
  join public.stages de on de.id = rr.dest_stage_id
  where rr.passenger_id = auth.uid()
    and rr.status = 'open'
    and rr.expires_at > now();
$$;

-- ---------------------------------------------------------------------------
-- Who may call these.
-- ---------------------------------------------------------------------------
revoke execute on function
  public.price_band(uuid, uuid, public.vehicle_type),
  public.create_ride_request(uuid, uuid, public.vehicle_type, integer),
  public.cancel_ride_request(),
  public.current_ride_request()
  from public;

grant execute on function
  public.price_band(uuid, uuid, public.vehicle_type),
  public.create_ride_request(uuid, uuid, public.vehicle_type, integer),
  public.cancel_ride_request(),
  public.current_ride_request()
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5. A passenger standing where the driver is, is a match
--
-- FOUND BY THE TEST BELOW THIS FILE, and it is the most likely match there
-- is. `match_requests_for_session` required `pickup_t > driver_t` -- strictly
-- ahead -- so a passenger waiting at the stage the driver is pulling out of
-- was excluded by a few metres of GPS noise. Exact equality never happens in
-- the field; being five metres past the stage does.
--
-- 100 m of tolerance behind the driver: longer than a bus stage, longer than
-- a GPS error, and short enough that it never means turning round in traffic.
-- `meters_ahead` already clamps to zero, so someone just behind reads as
-- "0 m ahead", which is what they are.
--
-- THIS IS THE CURRENT DEFINITION of the function. It has been replaced twice
-- since C3 -- once in `20261028000100_feed_nudge.sql` to stop a driver seeing
-- their own request, and here. Read this one.
--
-- The DROP below is load-bearing. `create or replace` only replaces a
-- function with the SAME signature; adding a parameter creates a second one
-- alongside the first, and a one-argument call then fails with
--
--     function public.match_requests_for_session(unknown) is not unique
--
-- which would have broken every driver feed the moment this migration was
-- pushed. `08_requesting_test.sql` asserts there is exactly one.
-- ---------------------------------------------------------------------------
drop function if exists public.match_requests_for_session(uuid);

create or replace function public.match_requests_for_session(
  p_session_id   uuid,
  p_behind_m     integer default 100
)
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
      -- Not your own: a driver is a passenger on their days off.
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
  where
    -- (a) the pickup is inside the corridor around this road
    st_dwithin(c.pickup, c.route_geog, c.corridor_m)
    -- (b) the pickup is ahead of the driver, or close enough behind to stop
    --     for. See the note above.
    and (c.pickup_t - c.driver_t) * c.route_m > -p_behind_m
    -- (c) the pickup is not past where the driver stops
    and c.pickup_t <= c.dest_t
    -- (d) and neither is the passenger's destination
    and c.drop_t   <= c.dest_t
  -- Nearest passenger ahead first. Never by price: sorting by money would
  -- turn a shared road into an auction.
  order by c.pickup_t asc;
$$;
