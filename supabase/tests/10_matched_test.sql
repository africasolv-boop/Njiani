-- Tests for the moment after a seat is claimed. Component C10.
--
-- The race itself has been settled by `accept_ride_request` since C3, and
-- `02_race_*.sql` proves it with two real connections. What this file is
-- about is the thing the claim unlocks and the security model otherwise
-- forbids: a phone number.
--
-- THE CLAIM: a number is readable by the other party on a LIVE seat, and by
-- nobody else, ever. Every other assertion here exists to show the "nobody
-- else" half.

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

-- ---------------------------------------------------------------------------
-- Fixtures: a driver, the passenger who claims a seat, and a bystander.
-- ---------------------------------------------------------------------------
insert into auth.users (id, phone) values
  ('ca000000-0000-4000-8000-000000000001', '+255754000091'),  -- driver
  ('ca000000-0000-4000-8000-000000000002', '+255712000091'),  -- passenger
  ('ca000000-0000-4000-8000-000000000003', '+255713000091');  -- bystander

update public.profiles set display_name = 'Juma Mwinyi'
 where id = 'ca000000-0000-4000-8000-000000000001';
update public.profiles set display_name = 'Neema'
 where id = 'ca000000-0000-4000-8000-000000000002';

insert into public.drivers
  (profile_id, vehicle_type, plate, colour, licence_path, status, rating,
   trips_count)
values ('ca000000-0000-4000-8000-000000000001', 'bajaj', 'T 482 DKT', 'Blue',
        'ca000000-0000-4000-8000-000000000001/licence.jpg', 'approved',
        4.8, 312);

create temporary table f (k text primary key, v uuid) on commit drop;
insert into f select 'west', id from public.routes where direction_label = 'Westbound';
insert into f select 'ubungo', id from public.stages
  where name = 'Ubungo Mataa' and route_id = (select v from f where k = 'west');
insert into f select 'shekilango', id from public.stages
  where name = 'Shekilango' and route_id = (select v from f where k = 'west');
insert into f select 'mwisho', id from public.stages
  where name = 'Kimara Mwisho' and route_id = (select v from f where k = 'west');
grant select on f to authenticated;

insert into public.driver_sessions
  (id, driver_id, route_id, dest_stage_id, vehicle_type, seats_total,
   seats_free, last_pos, last_pos_at)
values ('ca111111-0000-4000-8000-000000000001',
        'ca000000-0000-4000-8000-000000000001',
        (select v from f where k = 'west'),
        (select v from f where k = 'mwisho'),
        'bajaj', 3, 3,
        (select geom from public.stages where id = (select v from f where k = 'ubungo')),
        now());

insert into public.ride_requests
  (id, passenger_id, route_id, pickup, pickup_stage_id, dest_stage_id,
   vehicle_type, offer_price)
values ('ca222222-0000-4000-8000-000000000001',
        'ca000000-0000-4000-8000-000000000002',
        (select v from f where k = 'west'),
        (select geom from public.stages where id = (select v from f where k = 'shekilango')),
        (select v from f where k = 'shekilango'),
        (select v from f where k = 'mwisho'),
        'bajaj', 1500);

-- ===========================================================================
-- Before the claim, nobody is anybody
-- ===========================================================================
set local role authenticated;
select set_config('njiani.test_uid', 'ca000000-0000-4000-8000-000000000002', true);

select pg_temp.check(
  'a waiting passenger has no seat, and no number',
  (select count(*)::integer from public.current_trip_seat()),
  0
);

-- The reason the reveal needs a definer function at all: a passenger cannot
-- read a driver's row, which is right. A feed full of phone numbers would be
-- a directory.
select pg_temp.check(
  'a passenger cannot read the driver''s profile directly',
  (select count(*)::integer from public.profiles
    where id = 'ca000000-0000-4000-8000-000000000001'),
  0
);

reset role;

-- ===========================================================================
-- The claim
-- ===========================================================================
set local role authenticated;
select set_config('njiani.test_uid', 'ca000000-0000-4000-8000-000000000001', true);

select pg_temp.check(
  'the driver claims the seat',
  (select ok from public.accept_ride_request(
     'ca222222-0000-4000-8000-000000000001',
     'ca111111-0000-4000-8000-000000000001')),
  true
);

select pg_temp.check(
  'and the second tap on the same passenger is told why',
  (select reason from public.accept_ride_request(
     'ca222222-0000-4000-8000-000000000001',
     'ca111111-0000-4000-8000-000000000001')),
  'already_taken'
);

select pg_temp.check(
  'a seat is gone from the vehicle',
  (select seats_free::integer from public.driver_sessions
    where id = 'ca111111-0000-4000-8000-000000000001'),
  2
);

-- The agreed price is copied at claim time and must not move afterwards,
-- whatever happens to the request row.
select pg_temp.check(
  'the price is fixed at what was offered',
  (select price from public.trip_seats
    where passenger_id = 'ca000000-0000-4000-8000-000000000002'),
  1500
);

reset role;

-- ===========================================================================
-- Now the passenger knows who is coming
-- ===========================================================================
set local role authenticated;
select set_config('njiani.test_uid', 'ca000000-0000-4000-8000-000000000002', true);

select pg_temp.check(
  'the driver''s number is revealed, now that there is a seat',
  (select driver_phone from public.current_trip_seat()),
  '255754000091'
);

select pg_temp.check(
  'with who they are and what they are driving',
  (select driver_name || ' / ' || plate || ' / ' || colour || ' / '
          || vehicle_type::text
     from public.current_trip_seat()),
  'Juma Mwinyi / T 482 DKT / Blue / bajaj'
);

select pg_temp.check(
  'and what was agreed',
  (select price || ' from ' || pickup_name || ' to ' || dest_name
     from public.current_trip_seat()),
  '1500 from Shekilango to Kimara Mwisho'
);

-- The design asks for it by name: a shared bajaj is not a surprise anyone
-- should get on arrival.
select pg_temp.check(
  'how full the vehicle already is',
  (select seats_taken from public.current_trip_seat()),
  1
);

-- Straight-line for now; OSRM at C14. Ubungo to Shekilango is a little under
-- a kilometre of road.
select pg_temp.check(
  'how far away the driver is',
  (select metres_away between 500 and 1500 from public.current_trip_seat()),
  true
);

reset role;

-- ===========================================================================
-- NOBODY ELSE. This is the half that matters.
-- ===========================================================================
set local role authenticated;
select set_config('njiani.test_uid', 'ca000000-0000-4000-8000-000000000003', true);

select pg_temp.check(
  'a bystander sees no seat',
  (select count(*)::integer from public.current_trip_seat()),
  0
);

select pg_temp.check(
  'and cannot read the seat row either',
  (select count(*)::integer from public.trip_seats),
  0
);

select pg_temp.check(
  'and cannot cancel somebody else''s seat',
  public.cancel_my_seat(),
  false
);

select set_config('njiani.test_uid', '', true);

select pg_temp.check(
  'a signed-out client sees nothing at all',
  (select count(*)::integer from public.current_trip_seat()),
  0
);

reset role;

-- ===========================================================================
-- The number stops being anybody's business when the trip ends
-- ===========================================================================
update public.trip_seats set state = 'dropped', dropped_at = now()
 where passenger_id = 'ca000000-0000-4000-8000-000000000002';

set local role authenticated;
select set_config('njiani.test_uid', 'ca000000-0000-4000-8000-000000000002', true);

select pg_temp.check(
  'a finished trip reveals no number',
  (select count(*)::integer from public.current_trip_seat()),
  0
);

reset role;

-- ===========================================================================
-- Cancelling before the driver arrives
-- ===========================================================================
update public.trip_seats set state = 'claimed', dropped_at = null
 where passenger_id = 'ca000000-0000-4000-8000-000000000002';

set local role authenticated;
select set_config('njiani.test_uid', 'ca000000-0000-4000-8000-000000000002', true);

select pg_temp.check('a passenger may withdraw', public.cancel_my_seat(), true);

select pg_temp.check(
  'the seat is gone from their screen',
  (select count(*)::integer from public.current_trip_seat()),
  0
);

reset role;

select pg_temp.check(
  'the vehicle has its seat back',
  (select seats_free::integer from public.driver_sessions
    where id = 'ca111111-0000-4000-8000-000000000001'),
  3
);

-- Not reopened. A passenger who changed their mind is not still waiting, and
-- re-offering the request would send a second driver to somebody who has
-- gone.
select pg_temp.check(
  'the request is not put back on the road',
  (select status::text from public.ride_requests
    where id = 'ca222222-0000-4000-8000-000000000001'),
  'cancelled'
);

-- ===========================================================================
-- Live, so the screen changes without a tap
-- ===========================================================================
select pg_temp.check(
  'trip_seats is published for realtime',
  (select count(*)::integer from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'trip_seats'),
  1
);

rollback;
