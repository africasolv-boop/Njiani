-- The two pieces of logic that ARE the product.
--
-- Everything else in this schema is plumbing around these. If they are right,
-- Njiani works; if they are wrong, nothing else saves it.

-- ---------------------------------------------------------------------------
-- 1. Directional corridor matching
--
-- A driver heading to Kimara must see a passenger only if that passenger is
--   (a) near the road,
--   (b) ahead of where the driver currently is, and
--   (c) not stopping past where the driver is stopping.
--
-- (b) is the whole product. It is why this is PostGIS and not a proximity
-- search: "within 2km of me" is a different, and wrong, question.
--
-- ST_LineLocatePoint returns a 0-1 fraction along the route's LineString.
-- Because a route row runs in the direction of travel (see the routes
-- migration), comparing fractions is what makes "ahead" mean anything.
--
-- SECURITY DEFINER, and scoped to the caller's own session: this is the only
-- way a driver reads ride_requests. They hold no blanket read policy, so they
-- cannot enumerate the table (ARCHITECTURE §8).
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
set search_path = public
as $$
  with session as (
    select
      ds.vehicle_type,
      ds.seats_free,
      ds.route_id,
      r.geom::geometry as route_geom,
      r.geom           as route_geog,
      r.corridor_m,
      -- Where the driver is along the road, 0-1. No GPS fix yet means the
      -- start of the route: a driver who has just gone online should see the
      -- whole road ahead, not an empty feed.
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
      -- A driver reads only their own session. Passing someone else's id
      -- returns nothing rather than someone else's feed.
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
      s.route_m,
      st_linelocatepoint(s.route_geom, rr.pickup::geometry)   as pickup_t,
      st_linelocatepoint(s.route_geom, de.geom::geometry)     as drop_t,
      s.dest_t,
      s.corridor_m,
      s.route_geog,
      rr.pickup
    from public.ride_requests rr
    join public.stages de on de.id = rr.dest_stage_id
    left join public.stages ps on ps.id = rr.pickup_stage_id
    cross join session s
    where rr.status = 'open'
      and rr.expires_at > now()
      and rr.vehicle_type = s.vehicle_type
      and rr.route_id     = s.route_id
      and s.seats_free    > 0
  )
  select
    c.id,
    coalesce(c.pickup_name, 'On the road'),
    coalesce(c.pickup_name_sw, 'Barabarani'),
    c.dest_name,
    c.dest_name_sw,
    c.offer_price,
    -- Distance along the road, not as the crow flies: "400 m ahead" has to
    -- mean 400 m of driving.
    greatest(0, round((c.pickup_t - c.driver_t) * c.route_m))::integer,
    c.created_at
  from candidate c
  where
    -- (a) the pickup is inside the corridor around this road
    st_dwithin(c.pickup, c.route_geog, c.corridor_m)
    -- (b) the pickup is AHEAD of the driver
    and c.pickup_t > c.driver_t
    -- (c) the pickup is not past where the driver stops
    and c.pickup_t <= c.dest_t
    -- (c) and neither is the passenger's destination
    and c.drop_t   <= c.dest_t
  -- Nearest passenger ahead first. Never by price: sorting by money would
  -- turn a shared road into an auction.
  order by c.pickup_t asc;
$$;

comment on function public.match_requests_for_session(uuid) is
  'The driver feed. Corridor + ahead-of-me + not-past-my-stop, ordered nearest first.';

-- ---------------------------------------------------------------------------
-- 2. Race-safe seat claiming
--
-- Two drivers WILL tap Pickup on the same passenger in the same second. The
-- design already shows the losing state ("Taken by another driver"), so the
-- only question is whether the database decides it or the UI pretends to.
--
-- The race is settled by a single UPDATE that can only move a request off
-- 'open' once. Everything else follows from whether that UPDATE matched a row.
-- ---------------------------------------------------------------------------
create or replace function public.accept_ride_request(
  p_request_id uuid,
  p_session_id uuid
)
returns table (ok boolean, reason text, seat_id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seats     smallint;
  v_driver    uuid;
  v_price     integer;
  v_passenger uuid;
  v_seat      uuid;
begin
  -- Lock the session row first, and always first: a consistent lock order is
  -- what stops two concurrent claims deadlocking against each other.
  select ds.seats_free, ds.driver_id
    into v_seats, v_driver
  from public.driver_sessions ds
  where ds.id = p_session_id
    and ds.status = 'online'
    and ds.driver_id = auth.uid()
  for update;

  if not found then
    return query select false, 'no_session'::text, null::uuid;
    return;
  end if;

  if v_seats < 1 then
    return query select false, 'seats_full'::text, null::uuid;
    return;
  end if;

  -- THE RACE IS DECIDED HERE. Only one transaction can move this row off
  -- 'open'; the second one matches nothing and is told so.
  update public.ride_requests rr
     set status = 'claimed', claimed_at = now()
   where rr.id = p_request_id
     and rr.status = 'open'
     and rr.expires_at > now()
  returning rr.offer_price, rr.passenger_id
    into v_price, v_passenger;

  if not found then
    return query select false, 'already_taken'::text, null::uuid;
    return;
  end if;

  update public.driver_sessions
     set seats_free = seats_free - 1
   where id = p_session_id;

  insert into public.trip_seats
    (request_id, session_id, driver_id, passenger_id, price, state)
  values
    (p_request_id, p_session_id, v_driver, v_passenger, v_price, 'claimed')
  returning id into v_seat;

  return query select true, 'ok'::text, v_seat;
end;
$$;

comment on function public.accept_ride_request(uuid, uuid) is
  'Atomic seat claim. The loser gets already_taken, never a half-claimed seat.';

-- ---------------------------------------------------------------------------
-- 3. Releasing a seat
--
-- A cancelled or no-show seat frees the seat and returns the request to the
-- road, so the passenger is not stranded by a driver who changed their mind.
-- ---------------------------------------------------------------------------
create or replace function public.release_trip_seat(
  p_seat_id uuid,
  p_reopen  boolean default true
)
returns table (ok boolean, reason text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session uuid;
  v_request uuid;
  v_state   public.seat_state;
begin
  select ts.session_id, ts.request_id, ts.state
    into v_session, v_request, v_state
  from public.trip_seats ts
  join public.driver_sessions ds on ds.id = ts.session_id
  where ts.id = p_seat_id
    and (ts.passenger_id = auth.uid() or ds.driver_id = auth.uid())
  for update;

  if not found then
    return query select false, 'not_found'::text;
    return;
  end if;

  if v_state in ('dropped', 'cancelled') then
    return query select false, 'already_closed'::text;
    return;
  end if;

  update public.trip_seats
     set state = 'cancelled', cancelled_at = now()
   where id = p_seat_id;

  update public.driver_sessions
     set seats_free = least(seats_free + 1, seats_total)
   where id = v_session;

  update public.ride_requests
     set status       = case
                          when p_reopen then 'open'::public.request_status
                          else 'cancelled'::public.request_status
                        end,
         claimed_at   = null,
         cancelled_at = case when p_reopen then null else now() end,
         -- A reopened request gets its full window back rather than whatever
         -- was left of it: the passenger did not cause this.
         expires_at   = case
                          when p_reopen then now() + interval '10 minutes'
                          else expires_at
                        end
   where id = v_request;

  return query select true, 'ok'::text;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Stage mode (ARCHITECTURE §13.1)
--
-- For a driver parked with no heading chosen: the same corridor question,
-- grouped by destination instead of listed. Counts only, never identities --
-- a parked driver has no claim on anyone.
-- ---------------------------------------------------------------------------
create or replace function public.demand_near(
  p_point        geography(Point, 4326),
  p_vehicle_type public.vehicle_type,
  p_radius_m     integer default 2000
)
returns table (
  dest_stage_id uuid,
  dest_stage    text,
  dest_stage_sw text,
  route_id      uuid,
  waiting       integer,
  low_offer     integer,
  high_offer    integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    de.id,
    de.name,
    de.name_sw,
    rr.route_id,
    count(*)::integer,
    min(rr.offer_price)::integer,
    max(rr.offer_price)::integer
  from public.ride_requests rr
  join public.stages de on de.id = rr.dest_stage_id
  where rr.status = 'open'
    and rr.expires_at > now()
    and rr.vehicle_type = p_vehicle_type
    and st_dwithin(rr.pickup, p_point, p_radius_m)
  group by de.id, de.name, de.name_sw, rr.route_id
  order by count(*) desc, de.name asc;
$$;

-- ---------------------------------------------------------------------------
-- 5. Expiring stale requests
--
-- Rows are kept, not deleted. An unmatched expiry carries its offer, its
-- destination and its time of day, which is the fastest route to real price
-- bands -- rejected offers say more about the floor than accepted ones do.
-- ---------------------------------------------------------------------------
create or replace function public.expire_stale_requests()
returns integer
language sql
security definer
set search_path = public
as $$
  with expired as (
    update public.ride_requests
       set status = 'expired'
     where status = 'open'
       and expires_at <= now()
    returning 1
  )
  select count(*)::integer from expired;
$$;
