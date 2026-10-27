-- Declaring a heading, and going online. Component C7.
--
-- This is the row that makes Njiani not a ride-hailing app: the driver
-- chooses a direction BEFORE seeing a single request, and the feed is derived
-- from it. Three things have to be true of every session, and none of them
-- can be left to the client:
--
--   1. The driver is approved. The router holds an unapproved driver at the
--      C6 gate, but a gate in the UI is not a gate.
--   2. The vehicle is the one on the driver's record. `driver_sessions` has a
--      CHECK tying seats_total to vehicle_type, and nothing tying either to
--      `drivers` -- so a boda rider could open a bajaj session with three
--      seats and be offered three-seat work. Both columns are read from the
--      driver's row here and the client is not asked.
--   3. Seats already carrying somebody are not offered again. "Changing
--      direction ends the session and starts a new one. Claimed seats
--      survive" (design, dDirection) -- which means the new session starts
--      with the seats that are genuinely free, not with a full vehicle.

set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- 0. How many seats a vehicle has
--
-- A physical fact, not a setting. It was already written into the
-- `seats_match_vehicle` CHECK on `driver_sessions`; this is the same fact as
-- something the rest of the schema can call, so a session is built from it
-- rather than from a number the client sent that the CHECK then happens to
-- accept.
-- ---------------------------------------------------------------------------
create or replace function public.seats_for(p_vehicle public.vehicle_type)
returns smallint
language sql
immutable
as $$
  select case p_vehicle
           when 'bajaj' then 3::smallint
           when 'boda'  then 1::smallint
         end;
$$;

comment on function public.seats_for(public.vehicle_type) is
  'C7. Seats per vehicle type, matching the seats_match_vehicle CHECK.';

-- ---------------------------------------------------------------------------
-- 1. Where am I, and where can I go from here
--
-- `nearest_stage` names the place the driver is standing, for the header.
-- `destinations_ahead` is the destination list, and it is the directional
-- logic in miniature: a stage counts only if it is further along the route
-- than the driver is, by the same ST_LineLocatePoint fraction the matching
-- query uses.
--
-- That is also what picks the direction. Ubungo->Kimara and Kimara->Ubungo
-- are two route rows over the same road, so the driver's point sits in both
-- corridors -- but any given stage is ahead on exactly one of them. Choosing
-- a destination chooses a heading, with no compass and no extra question.
-- ---------------------------------------------------------------------------
create or replace function public.nearest_stage(p_point geography)
returns table (
  stage_id   uuid,
  route_id   uuid,
  name       text,
  name_sw    text,
  metres     double precision
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select s.id, s.route_id, s.name, s.name_sw, st_distance(s.geom, p_point)
  from public.stages s
  join public.routes r on r.id = s.route_id
  where s.active and r.active
  order by s.geom <-> p_point
  limit 1;
$$;

create or replace function public.destinations_ahead(
  p_point       geography,
  -- How far ahead a stage has to be before it is worth offering.
  --
  -- This does two jobs at once. It drops the stage the driver is standing at,
  -- which is not a destination, and it forgives a GPS fix that has put them a
  -- little past it -- neither a phone nor a bus stage is precise to the metre.
  -- 400m is comfortably under the ~800m gap between stages on this corridor,
  -- so it never removes a real option.
  p_min_ahead_m integer default 400
)
returns table (
  route_id        uuid,
  direction_label text,
  stage_id        uuid,
  name            text,
  name_sw         text,
  seq             integer,
  metres_ahead    double precision
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  with here as (
    select
      r.id   as route_id,
      r.direction_label,
      st_length(r.geom)                                as route_m,
      st_linelocatepoint(r.geom::geometry, p_point::geometry) as driver_t,
      r.geom
    from public.routes r
    where r.active
      and st_dwithin(r.geom, p_point, r.corridor_m)
  )
  select
    h.route_id,
    h.direction_label,
    s.id,
    s.name,
    s.name_sw,
    s.seq,
    (st_linelocatepoint(h.geom::geometry, s.geom::geometry) - h.driver_t)
      * h.route_m
  from here h
  join public.stages s on s.route_id = h.route_id and s.active
  where (st_linelocatepoint(h.geom::geometry, s.geom::geometry) - h.driver_t)
          * h.route_m >= p_min_ahead_m
  -- By seq, in the direction of travel. Never alphabetical: a list that puts
  -- Kimara Mwisho above Ubungo is a list nobody can read at a stage.
  order by h.direction_label, s.seq;
$$;

-- The same list, from a stage the driver named instead of a GPS fix.
--
-- The no-GPS fallback: "ask permission with the reason, then fall back to
-- picking a start stage by hand" (design, dDirection). Resolving the stage to
-- its coordinates here rather than on the client keeps every piece of
-- geometry on this side of the wire -- a `geography` column reaches PostgREST
-- as hex EWKB, and a client that has to parse that to ask a question is a
-- client that will get it wrong.
create or replace function public.destinations_from_stage(
  p_stage_id    uuid,
  p_min_ahead_m integer default 400
)
returns table (
  route_id        uuid,
  direction_label text,
  stage_id        uuid,
  name            text,
  name_sw         text,
  seq             integer,
  metres_ahead    double precision
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select d.*
  from public.stages s,
       lateral public.destinations_ahead(s.geom, p_min_ahead_m) d
  where s.id = p_stage_id and s.active;
$$;

-- ---------------------------------------------------------------------------
-- 2. Going online
--
-- Ends any session the driver already has and opens a new one, in one
-- statement-ordered block. `driver_sessions_one_online_idx` makes being
-- online twice impossible, so this is also the only way to change direction
-- without tripping it.
-- ---------------------------------------------------------------------------
create or replace function public.go_online(
  p_route_id      uuid,
  p_dest_stage_id uuid,
  p_pos           geography default null,
  -- Where the driver said they are, when the device could not say. The
  -- session needs a position either way: `match_requests_for_session` treats
  -- a null `last_pos` as the start of the route, which for a driver already
  -- halfway along it means a feed full of passengers behind them.
  p_from_stage_id uuid default null
)
returns public.driver_sessions
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_driver  public.drivers;
  v_session public.driver_sessions;
  v_held    integer;
  v_pos     geography := p_pos;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;

  select * into v_driver from public.drivers where profile_id = auth.uid();

  if v_driver.profile_id is null then
    raise exception 'no driver application on file' using errcode = 'P0002';
  end if;

  -- The C6 gate, enforced where it cannot be skipped.
  if v_driver.status <> 'approved' then
    raise exception 'driver is % , not approved', v_driver.status
      using errcode = '42501';
  end if;

  -- The destination has to be on the route being declared. Without this a
  -- driver could pair a westbound route with an eastbound stage and sit in a
  -- session whose feed can never match anything.
  if not exists (
    select 1
    from public.stages s
    join public.routes r on r.id = s.route_id
    where s.id = p_dest_stage_id
      and s.route_id = p_route_id
      and s.active and r.active
  ) then
    raise exception 'that destination is not a stage on that route'
      using errcode = '22023';
  end if;

  -- Seats that are still carrying somebody. A direction change keeps them --
  -- the passenger is in the vehicle either way -- so the new session must not
  -- offer them again.
  select count(*) into v_held
  from public.trip_seats
  where driver_id = auth.uid() and state in ('claimed', 'aboard');

  if v_held >= public.seats_for(v_driver.vehicle_type) then
    raise exception 'every seat is already taken' using errcode = '22023';
  end if;

  if v_pos is null and p_from_stage_id is not null then
    select geom into v_pos from public.stages where id = p_from_stage_id;
  end if;

  update public.driver_sessions
     set status = 'offline', ended_at = now()
   where driver_id = auth.uid() and status = 'online';

  insert into public.driver_sessions
    (driver_id, route_id, dest_stage_id, vehicle_type, seats_total,
     seats_free, last_pos, last_pos_at)
  values (
    auth.uid(),
    p_route_id,
    p_dest_stage_id,
    v_driver.vehicle_type,
    public.seats_for(v_driver.vehicle_type),
    public.seats_for(v_driver.vehicle_type) - v_held,
    v_pos,
    case when v_pos is null then null else now() end
  )
  returning * into v_session;

  return v_session;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Going offline
--
-- Ends the session and nothing else. A claimed seat is a passenger who is
-- either waiting or already in the vehicle, and closing an app is not a
-- cancellation -- the driver still owes them the trip. Cancelling a seat is
-- `release_trip_seat`, deliberately a separate, deliberate act.
-- ---------------------------------------------------------------------------
create or replace function public.go_offline()
returns integer
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_closed integer;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;

  update public.driver_sessions
     set status = 'offline', ended_at = now()
   where driver_id = auth.uid() and status = 'online';

  get diagnostics v_closed = row_count;
  return v_closed;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Position
--
-- The one thing about a session the client legitimately writes. Throttled on
-- the device, because battery and data cost a driver real money; the
-- structural columns below are not writable at all.
-- ---------------------------------------------------------------------------
create or replace function public.report_position(p_pos geography)
returns void
language sql
security definer
set search_path = public, extensions
as $$
  update public.driver_sessions
     set last_pos = p_pos, last_pos_at = now()
   where driver_id = auth.uid() and status = 'online';
$$;

-- ---------------------------------------------------------------------------
-- 5. What a driver may write on their own session
--
-- `sessions_own` is a `for all` policy, so without this a driver could insert
-- a session by hand -- declaring three seats on a motorcycle, or going online
-- while still pending -- and could set `seats_free` on their own row. The
-- functions above are `security definer`, so they are unaffected.
-- ---------------------------------------------------------------------------
revoke insert, update on public.driver_sessions from authenticated;
grant update (last_pos, last_pos_at) on public.driver_sessions to authenticated;

revoke execute on function
  public.go_online(uuid, uuid, geography, uuid),
  public.destinations_from_stage(uuid, integer),
  public.go_offline(),
  public.report_position(geography),
  public.nearest_stage(geography),
  public.destinations_ahead(geography, integer)
  from public;

grant execute on function
  public.go_online(uuid, uuid, geography, uuid),
  public.destinations_from_stage(uuid, integer),
  public.go_offline(),
  public.report_position(geography),
  public.nearest_stage(geography),
  public.destinations_ahead(geography, integer)
  to authenticated;
