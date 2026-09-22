-- Tests for the rest of the trip lifecycle: releasing a seat, expiry, and
-- stage-mode demand.

\set ON_ERROR_STOP on
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

insert into auth.users (id, phone) values
  ('ffffffff-0000-4000-8000-000000000001', '+255754000031'),
  ('ffffffff-0000-4000-8000-000000000002', '+255712000031'),
  ('ffffffff-0000-4000-8000-000000000003', '+255712000032');

insert into public.drivers (profile_id, vehicle_type, plate, colour, licence_path, status)
values ('ffffffff-0000-4000-8000-000000000001', 'bajaj', 'T 777 CCC', 'Blue',
        'l/7.jpg', 'approved');

create temporary table f (k text primary key, v uuid) on commit drop;
insert into f
select 'route', id from public.routes where direction_label = 'Westbound';
insert into f select 'korogwe', id from public.stages
  where name = 'Kimara Korogwe' and route_id = (select v from f where k='route');
insert into f select 'shekilango', id from public.stages
  where name = 'Shekilango' and route_id = (select v from f where k='route');
insert into f select 'ubungo', id from public.stages
  where name = 'Ubungo Bus Terminal' and route_id = (select v from f where k='route');

insert into public.driver_sessions
  (id, driver_id, route_id, dest_stage_id, vehicle_type, seats_total, seats_free,
   last_pos, last_pos_at)
values ('88888888-0000-4000-8000-000000000001',
        'ffffffff-0000-4000-8000-000000000001',
        (select v from f where k='route'),
        (select v from f where k='korogwe'),
        'bajaj', 3, 3,
        (select geom from public.stages where id = (select v from f where k='ubungo')),
        now());

insert into public.ride_requests
  (id, passenger_id, route_id, pickup, pickup_stage_id, dest_stage_id,
   vehicle_type, offer_price)
values ('44444444-0000-4000-8000-000000000001',
        'ffffffff-0000-4000-8000-000000000002',
        (select v from f where k='route'),
        (select geom from public.stages where id = (select v from f where k='shekilango')),
        (select v from f where k='shekilango'),
        (select v from f where k='korogwe'),
        'bajaj', 1500);

select set_config('njiani.test_uid', 'ffffffff-0000-4000-8000-000000000001', true);

-- ---------------------------------------------------------------------------
-- Claim, then release
-- ---------------------------------------------------------------------------
select pg_temp.check('a claim succeeds',
  (select ok from public.accept_ride_request(
    '44444444-0000-4000-8000-000000000001',
    '88888888-0000-4000-8000-000000000001')), true);

select pg_temp.check('the seat is taken',
  (select seats_free::integer from public.driver_sessions
    where id = '88888888-0000-4000-8000-000000000001'), 2);

select pg_temp.check('claiming the same request twice is refused',
  (select reason from public.accept_ride_request(
    '44444444-0000-4000-8000-000000000001',
    '88888888-0000-4000-8000-000000000001')), 'already_taken'::text);

-- The driver cancels. The passenger must not be stranded.
select pg_temp.check('releasing the seat succeeds',
  (select ok from public.release_trip_seat(
    (select id from public.trip_seats
      where request_id = '44444444-0000-4000-8000-000000000001'))), true);

select pg_temp.check('the seat comes back',
  (select seats_free::integer from public.driver_sessions
    where id = '88888888-0000-4000-8000-000000000001'), 3);

select pg_temp.check('the request returns to the road',
  (select status::text from public.ride_requests
    where id = '44444444-0000-4000-8000-000000000001'), 'open'::text);

select pg_temp.check('a reopened request gets a full window, not the remains',
  (select expires_at > now() + interval '9 minutes' from public.ride_requests
    where id = '44444444-0000-4000-8000-000000000001'), true);

select pg_temp.check('it can be claimed again after release',
  (select ok from public.accept_ride_request(
    '44444444-0000-4000-8000-000000000001',
    '88888888-0000-4000-8000-000000000001')), true);

-- ---------------------------------------------------------------------------
-- Expiry keeps the row -- it is the pricing dataset
-- ---------------------------------------------------------------------------
insert into public.ride_requests
  (id, passenger_id, route_id, pickup, pickup_stage_id, dest_stage_id,
   vehicle_type, offer_price, expires_at)
values ('44444444-0000-4000-8000-000000000002',
        'ffffffff-0000-4000-8000-000000000003',
        (select v from f where k='route'),
        (select geom from public.stages where id = (select v from f where k='shekilango')),
        (select v from f where k='shekilango'),
        (select v from f where k='korogwe'),
        'bajaj', 700, now() - interval '1 second');

select pg_temp.check('expiry sweeps exactly the stale ones',
  public.expire_stale_requests(), 1);

select pg_temp.check('an expired request is kept, not deleted',
  (select status::text from public.ride_requests
    where id = '44444444-0000-4000-8000-000000000002'), 'expired'::text);

select pg_temp.check('its offer survives for the pricing dataset',
  (select offer_price from public.ride_requests
    where id = '44444444-0000-4000-8000-000000000002'), 700);

-- ---------------------------------------------------------------------------
-- Stage mode: counts, never identities
-- ---------------------------------------------------------------------------
insert into auth.users (id, phone) values
  ('ffffffff-0000-4000-8000-000000000004', '+255712000033');
insert into public.ride_requests
  (passenger_id, route_id, pickup, pickup_stage_id, dest_stage_id,
   vehicle_type, offer_price)
values ('ffffffff-0000-4000-8000-000000000004',
        (select v from f where k='route'),
        (select geom from public.stages where id = (select v from f where k='shekilango')),
        (select v from f where k='shekilango'),
        (select v from f where k='korogwe'),
        'bajaj', 1300);

select pg_temp.check('stage mode counts waiting passengers',
  (select waiting from public.demand_near(
    (select geom from public.stages where id = (select v from f where k='shekilango')),
    'bajaj', 2000) where dest_stage = 'Kimara Korogwe'), 1);

select pg_temp.check('stage mode reports the offer range',
  (select low_offer from public.demand_near(
    (select geom from public.stages where id = (select v from f where k='shekilango')),
    'bajaj', 2000) where dest_stage = 'Kimara Korogwe'), 1300);

select pg_temp.check('stage mode ignores somewhere far away',
  (select count(*)::integer from public.demand_near(
    st_setsrid(st_makepoint(39.28, -6.82), 4326)::geography, 'bajaj', 2000)), 0);

-- ---------------------------------------------------------------------------
-- Abandoned sessions
-- ---------------------------------------------------------------------------
update public.driver_sessions
   set last_pos_at = now() - interval '45 minutes',
       went_online_at = now() - interval '45 minutes'
 where id = '88888888-0000-4000-8000-000000000001';

select pg_temp.check('a silent driver is taken offline',
  public.close_abandoned_sessions(), 1);

select pg_temp.check('and stays offline',
  (select status from public.driver_sessions
    where id = '88888888-0000-4000-8000-000000000001'), 'offline'::text);

rollback;
