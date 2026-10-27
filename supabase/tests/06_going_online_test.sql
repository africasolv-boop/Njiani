-- Tests for declaring a heading and going online. Component C7.
--
-- The claim this file holds up: a session describes the vehicle that actually
-- exists, driven by someone who has actually been approved, with the seats
-- that are actually free. None of those three can be supplied by the client.

\set ON_ERROR_STOP on
set search_path = public, extensions;
begin;

create or replace function pg_temp.check(
  p_label text, p_actual anyelement, p_expected anyelement
) returns void language plpgsql as $$
begin
  if p_actual is distinct from p_expected then
    raise exception 'FAIL  %  expected % got %', p_label, p_expected, p_actual;
  end if;
  raise notice 'ok    %', p_label;
end $$;

create or replace function pg_temp.errcode(p_sql text)
returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception
  when others then return sqlstate;
end $$;

-- ---------------------------------------------------------------------------
-- Fixtures: an approved bajaj driver, an approved boda rider, one still
-- pending, and a passenger.
-- ---------------------------------------------------------------------------
insert into auth.users (id, phone) values
  ('a7000000-0000-4000-8000-000000000001', '+255754000041'),  -- bajaj, approved
  ('a7000000-0000-4000-8000-000000000002', '+255712000041'),  -- boda, approved
  ('a7000000-0000-4000-8000-000000000003', '+255713000041'),  -- pending
  ('a7000000-0000-4000-8000-000000000004', '+255715000041');  -- passenger

insert into public.drivers
  (profile_id, vehicle_type, plate, colour, licence_path, status)
values
  ('a7000000-0000-4000-8000-000000000001', 'bajaj', 'T 777 AAA', 'Blue',
   'a7000000-0000-4000-8000-000000000001/licence.jpg', 'approved'),
  ('a7000000-0000-4000-8000-000000000002', 'boda', 'MC 777 BB', 'Black',
   'a7000000-0000-4000-8000-000000000002/licence.jpg', 'approved'),
  ('a7000000-0000-4000-8000-000000000003', 'bajaj', 'T 777 CCC', 'Green',
   'a7000000-0000-4000-8000-000000000003/licence.jpg', 'pending');

create temporary table f (k text primary key, v uuid) on commit drop;
insert into f select 'west', id from public.routes where direction_label = 'Westbound';
insert into f select 'east', id from public.routes where direction_label = 'Eastbound';
insert into f select 'ubungo', id from public.stages
  where name = 'Ubungo Mataa' and route_id = (select v from f where k = 'west');
insert into f select 'shekilango', id from public.stages
  where name = 'Shekilango' and route_id = (select v from f where k = 'west');
insert into f select 'mwisho', id from public.stages
  where name = 'Kimara Mwisho' and route_id = (select v from f where k = 'west');
insert into f select 'east_terminal', id from public.stages
  where name = 'Ubungo Bus Terminal' and route_id = (select v from f where k = 'east');

-- The fixture table is created by `postgres`, and most of this file runs as
-- `authenticated` to exercise the grants. Without this the first assertion
-- after the role switch fails with `permission denied for table f`, which
-- looks like the thing under test and is not.
grant select on f to authenticated;

-- ===========================================================================
-- seats_for -- the same physical fact as the seats_match_vehicle CHECK
-- ===========================================================================
select pg_temp.check('a bajaj seats three', public.seats_for('bajaj')::integer, 3);
select pg_temp.check('a boda seats one',    public.seats_for('boda')::integer, 1);

-- If these two ever disagree, a session built from seats_for() is refused by
-- the CHECK and going online stops working for everyone.
select pg_temp.check(
  'seats_for agrees with the table constraint',
  pg_temp.errcode($sql$
    insert into public.driver_sessions
      (driver_id, route_id, dest_stage_id, vehicle_type, seats_total, seats_free)
    select 'a7000000-0000-4000-8000-000000000001',
           (select v from f where k = 'west'),
           (select v from f where k = 'mwisho'),
           'bajaj', public.seats_for('bajaj'), public.seats_for('bajaj')
  $sql$),
  null
);
delete from public.driver_sessions;

-- ===========================================================================
-- Act as the APPROVED BAJAJ DRIVER
-- ===========================================================================
set local role authenticated;
select set_config('njiani.test_uid', 'a7000000-0000-4000-8000-000000000001', true);

-- ---------------------------------------------------------------------------
-- Where am I, and where can I go
-- ---------------------------------------------------------------------------
select pg_temp.check(
  'nearest_stage names the place the driver is standing',
  (select name from public.nearest_stage(
     (select geom from public.stages where id = (select v from f where k = 'ubungo')))),
  'Ubungo Mataa'
);

-- The directional logic in miniature. Standing at Ubungo, Kimara Mwisho is
-- ahead westbound and is not a destination eastbound.
select pg_temp.check(
  'a stage ahead on this route is offered',
  (select count(*)::integer from public.destinations_ahead(
     (select geom from public.stages where id = (select v from f where k = 'ubungo')))
    where stage_id = (select v from f where k = 'mwisho')),
  1
);

select pg_temp.check(
  'the stage the driver is standing at is not a destination',
  (select count(*)::integer from public.destinations_ahead(
     (select geom from public.stages where id = (select v from f where k = 'ubungo')))
    where name = 'Ubungo Mataa'),
  0
);

-- Standing at Kimara Mwisho, the far west end: nothing is ahead westbound,
-- and the whole corridor is ahead eastbound. If this ever returns westbound
-- rows, the app is offering trips into the sea.
select pg_temp.check(
  'nothing is ahead at the end of the route',
  (select count(*)::integer from public.destinations_ahead(
     (select geom from public.stages where id = (select v from f where k = 'mwisho')))
    where direction_label = 'Westbound'),
  0
);

select pg_temp.check(
  'the other direction is offered from the same point',
  (select count(*)::integer > 0 from public.destinations_ahead(
     (select geom from public.stages where id = (select v from f where k = 'mwisho')))
    where direction_label = 'Eastbound'),
  true
);

-- Ordered by seq, in the direction of travel. A list that puts Kimara Mwisho
-- above Shekilango is a list nobody can read at a stage.
select pg_temp.check(
  'destinations come back in route order, not alphabetical',
  (select string_agg(name, ' > ' order by ord)
     from (select name, row_number() over () as ord
             from public.destinations_ahead(
               (select geom from public.stages where id = (select v from f where k = 'ubungo')))
            where direction_label = 'Westbound') d),
  'Shekilango > Ubungo Maji > Riverside > Kibo > Bucha > Kimara Suka > '
  'Kimara Korogwe > Kimara Mwisho'
);

-- ---------------------------------------------------------------------------
-- Going online
-- ---------------------------------------------------------------------------
select pg_temp.check(
  'a driver cannot insert a session by hand',
  pg_temp.errcode($sql$
    insert into public.driver_sessions
      (driver_id, route_id, dest_stage_id, vehicle_type, seats_total, seats_free)
    select 'a7000000-0000-4000-8000-000000000001',
           (select v from f where k = 'west'),
           (select v from f where k = 'mwisho'),
           'bajaj', 3, 3
  $sql$),
  '42501'
);

select pg_temp.check(
  'a destination on another route is refused',
  pg_temp.errcode(format($sql$
    select public.go_online(%L, %L)
  $sql$, (select v from f where k = 'west'),
         (select v from f where k = 'east_terminal'))),
  '22023'
);

select pg_temp.check(
  'going online opens one session',
  (select status from public.go_online(
     (select v from f where k = 'west'),
     (select v from f where k = 'mwisho'),
     (select geom from public.stages where id = (select v from f where k = 'ubungo')))),
  'online'
);

select pg_temp.check(
  'it starts with every seat free',
  (select seats_free::integer || '/' || seats_total::integer
     from public.driver_sessions
    where driver_id = 'a7000000-0000-4000-8000-000000000001' and status = 'online'),
  '3/3'
);

select pg_temp.check(
  'a driver cannot hand themselves more free seats',
  pg_temp.errcode($sql$
    update public.driver_sessions set seats_free = 3
     where driver_id = 'a7000000-0000-4000-8000-000000000001'
  $sql$),
  '42501'
);

select pg_temp.check(
  'a driver CAN report their position',
  pg_temp.errcode($sql$
    select public.report_position(
      (select geom from public.stages where name = 'Shekilango' limit 1))
  $sql$),
  null
);

-- ---------------------------------------------------------------------------
-- Changing direction
-- ---------------------------------------------------------------------------
select pg_temp.check(
  'changing direction leaves exactly one session online',
  (select count(*)::integer from public.driver_sessions
    where driver_id = 'a7000000-0000-4000-8000-000000000001' and status = 'online'),
  1
);

select public.go_online(
  (select v from f where k = 'west'),
  (select v from f where k = 'shekilango'));

select pg_temp.check(
  'still exactly one, after changing',
  (select count(*)::integer from public.driver_sessions
    where driver_id = 'a7000000-0000-4000-8000-000000000001' and status = 'online'),
  1
);

select pg_temp.check(
  'the new heading is the one just chosen',
  (select dest_stage_id from public.driver_sessions
    where driver_id = 'a7000000-0000-4000-8000-000000000001' and status = 'online'),
  (select v from f where k = 'shekilango')
);

select pg_temp.check(
  'the old session is closed, not deleted',
  (select count(*)::integer from public.driver_sessions
    where driver_id = 'a7000000-0000-4000-8000-000000000001'
      and status = 'offline' and ended_at is not null),
  1
);

reset role;

-- ===========================================================================
-- A claimed seat survives a direction change, and is not offered again
-- ===========================================================================
insert into public.ride_requests
  (id, passenger_id, route_id, pickup, pickup_stage_id, dest_stage_id,
   vehicle_type, offer_price)
values ('a7111111-0000-4000-8000-000000000001',
        'a7000000-0000-4000-8000-000000000004',
        (select v from f where k = 'west'),
        (select geom from public.stages where id = (select v from f where k = 'shekilango')),
        (select v from f where k = 'shekilango'),
        (select v from f where k = 'mwisho'),
        'bajaj', 1500);

set local role authenticated;
select set_config('njiani.test_uid', 'a7000000-0000-4000-8000-000000000001', true);

select pg_temp.check(
  'a passenger claims a seat',
  (select ok from public.accept_ride_request(
     'a7111111-0000-4000-8000-000000000001',
     (select id from public.driver_sessions
       where driver_id = 'a7000000-0000-4000-8000-000000000001' and status = 'online'))),
  true
);

select public.go_online(
  (select v from f where k = 'west'),
  (select v from f where k = 'mwisho'));

-- The passenger is in the vehicle either way, so the seat is still theirs...
select pg_temp.check(
  'the claimed seat survives the change',
  (select count(*)::integer from public.trip_seats
    where driver_id = 'a7000000-0000-4000-8000-000000000001'
      and state = 'claimed'),
  1
);

-- ...and the new session must not offer it to somebody else. A full vehicle
-- here would mean two people sold the same seat.
select pg_temp.check(
  'the new session offers only the seats that are genuinely free',
  (select seats_free::integer || '/' || seats_total::integer
     from public.driver_sessions
    where driver_id = 'a7000000-0000-4000-8000-000000000001' and status = 'online'),
  '2/3'
);

-- ---------------------------------------------------------------------------
-- Going offline
-- ---------------------------------------------------------------------------
select pg_temp.check('going offline closes the session',
  public.go_offline(), 1);

select pg_temp.check(
  'nobody is online afterwards',
  (select count(*)::integer from public.driver_sessions
    where driver_id = 'a7000000-0000-4000-8000-000000000001' and status = 'online'),
  0
);

-- Closing an app is not a cancellation. The driver still owes the passenger
-- the trip; cancelling a seat is release_trip_seat, a separate deliberate act.
select pg_temp.check(
  'going offline does not cancel the passenger',
  (select state::text from public.trip_seats
    where driver_id = 'a7000000-0000-4000-8000-000000000001'),
  'claimed'
);

select pg_temp.check('going offline twice closes nothing',
  public.go_offline(), 0);

reset role;

-- ===========================================================================
-- Act as the BODA RIDER -- the vehicle comes from the record, not the client
-- ===========================================================================
set local role authenticated;
select set_config('njiani.test_uid', 'a7000000-0000-4000-8000-000000000002', true);

select public.go_online(
  (select v from f where k = 'west'),
  (select v from f where k = 'mwisho'));

select pg_temp.check(
  'a boda session has one seat, whatever the client would like',
  (select vehicle_type::text || ' ' || seats_total::integer
     from public.driver_sessions
    where driver_id = 'a7000000-0000-4000-8000-000000000002' and status = 'online'),
  'boda 1'
);

reset role;

-- ===========================================================================
-- Act as the PENDING DRIVER -- the C6 gate, enforced where it cannot be
-- skipped by navigating around a screen
-- ===========================================================================
set local role authenticated;
select set_config('njiani.test_uid', 'a7000000-0000-4000-8000-000000000003', true);

select pg_temp.check(
  'an unapproved driver cannot go online',
  pg_temp.errcode(format($sql$
    select public.go_online(%L, %L)
  $sql$, (select v from f where k = 'west'),
         (select v from f where k = 'mwisho'))),
  '42501'
);

reset role;

-- ===========================================================================
-- Act as the PASSENGER -- who is not a driver at all
-- ===========================================================================
set local role authenticated;
select set_config('njiani.test_uid', 'a7000000-0000-4000-8000-000000000004', true);

select pg_temp.check(
  'someone with no application cannot go online',
  pg_temp.errcode(format($sql$
    select public.go_online(%L, %L)
  $sql$, (select v from f where k = 'west'),
         (select v from f where k = 'mwisho'))),
  'P0002'
);

select pg_temp.check(
  'a passenger cannot see a driver session',
  (select count(*)::integer from public.driver_sessions),
  0
);

reset role;

rollback;
