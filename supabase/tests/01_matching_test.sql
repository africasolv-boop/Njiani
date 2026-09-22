-- Tests for match_requests_for_session(): the driver feed.
--
-- Run with supabase/tests/run.sh. Each assertion raises on failure, so the
-- script exits non-zero the moment anything is wrong.

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

-- ---------------------------------------------------------------------------
-- Fixtures: one driver, four passengers, on the westbound corridor.
-- ---------------------------------------------------------------------------
create temporary table t (k text primary key, v uuid) on commit drop;

insert into auth.users (id, phone) values
  ('aaaaaaaa-0000-4000-8000-000000000001', '+255754000001'),
  ('bbbbbbbb-0000-4000-8000-000000000001', '+255712000001'),
  ('bbbbbbbb-0000-4000-8000-000000000002', '+255712000002'),
  ('bbbbbbbb-0000-4000-8000-000000000003', '+255712000003'),
  ('bbbbbbbb-0000-4000-8000-000000000004', '+255712000004'),
  ('bbbbbbbb-0000-4000-8000-000000000005', '+255712000005');

insert into public.drivers (profile_id, vehicle_type, plate, colour, licence_path, status)
values ('aaaaaaaa-0000-4000-8000-000000000001', 'bajaj', 'T 482 DKT', 'Blue',
        'licences/juma.jpg', 'approved');

insert into t (k, v)
select 'route', id from public.routes where direction_label = 'Westbound';
insert into t (k, v)
select 'korogwe', id from public.stages s
 where s.name = 'Kimara Korogwe' and s.route_id = (select v from t where k='route');
insert into t (k, v)
select 'mwisho', id from public.stages s
 where s.name = 'Kimara Mwisho' and s.route_id = (select v from t where k='route');
insert into t (k, v)
select 'shekilango', id from public.stages s
 where s.name = 'Shekilango' and s.route_id = (select v from t where k='route');
insert into t (k, v)
select 'kibo', id from public.stages s
 where s.name = 'Kibo' and s.route_id = (select v from t where k='route');
insert into t (k, v)
select 'ubungo', id from public.stages s
 where s.name = 'Ubungo Bus Terminal' and s.route_id = (select v from t where k='route');

-- Driver is at Ubungo, heading west, stopping at Kimara Korogwe (seq 8).
-- Kimara Mwisho (seq 9) is BEYOND where they stop.
insert into public.driver_sessions
  (id, driver_id, route_id, dest_stage_id, vehicle_type, seats_total, seats_free,
   last_pos, last_pos_at)
values (
  '99999999-0000-4000-8000-000000000001',
  'aaaaaaaa-0000-4000-8000-000000000001',
  (select v from t where k='route'),
  (select v from t where k='korogwe'),
  'bajaj', 3, 3,
  (select geom from public.stages where id = (select v from t where k='ubungo')),
  now()
);

-- Act as the driver for every call below.
select set_config('njiani.test_uid', 'aaaaaaaa-0000-4000-8000-000000000001', true);

-- Helper to create a request.
create or replace function pg_temp.request(
  p_passenger uuid, p_pickup_stage uuid, p_dest_stage uuid,
  p_price integer default 1200,
  p_vehicle public.vehicle_type default 'bajaj',
  p_pickup geography default null,
  p_expires timestamptz default null
) returns uuid language plpgsql as $$
declare v_id uuid;
begin
  insert into public.ride_requests
    (passenger_id, route_id, pickup, pickup_stage_id, dest_stage_id,
     vehicle_type, offer_price, expires_at)
  values (
    p_passenger,
    (select route_id from public.stages where id = p_dest_stage),
    coalesce(p_pickup, (select geom from public.stages where id = p_pickup_stage)),
    p_pickup_stage, p_dest_stage, p_vehicle, p_price,
    coalesce(p_expires, now() + interval '10 minutes')
  ) returning id into v_id;
  return v_id;
end $$;

-- ===========================================================================
-- (b) AHEAD OF ME -- the assertion the whole product rests on
-- ===========================================================================

-- A passenger ahead at Shekilango, stopping at Kimara Korogwe.
select pg_temp.request(
  'bbbbbbbb-0000-4000-8000-000000000001',
  (select v from t where k='shekilango'),
  (select v from t where k='korogwe')
);

select pg_temp.check(
  'a passenger ahead on the road is matched',
  (select count(*)::integer from public.match_requests_for_session(
    '99999999-0000-4000-8000-000000000001')),
  1
);

-- Now move the driver PAST Shekilango, to Kibo. The same request is behind.
update public.driver_sessions
   set last_pos = (select geom from public.stages where id = (select v from t where k='kibo'))
 where id = '99999999-0000-4000-8000-000000000001';

select pg_temp.check(
  'a passenger behind the driver is NOT matched',
  (select count(*)::integer from public.match_requests_for_session(
    '99999999-0000-4000-8000-000000000001')),
  0
);

-- Put the driver back at Ubungo.
update public.driver_sessions
   set last_pos = (select geom from public.stages where id = (select v from t where k='ubungo'))
 where id = '99999999-0000-4000-8000-000000000001';

-- ===========================================================================
-- (c) NOT PAST MY STOP
-- ===========================================================================

select pg_temp.request(
  'bbbbbbbb-0000-4000-8000-000000000002',
  (select v from t where k='shekilango'),
  (select v from t where k='mwisho')      -- one stage beyond the driver's
);

select pg_temp.check(
  'a passenger going past the driver''s destination is NOT matched',
  (select count(*)::integer from public.match_requests_for_session(
    '99999999-0000-4000-8000-000000000001')),
  1  -- still only the first passenger
);

-- ===========================================================================
-- (a) INSIDE THE CORRIDOR
-- ===========================================================================

-- Same road position, but 2 km north of it -- a different neighbourhood.
select pg_temp.request(
  'bbbbbbbb-0000-4000-8000-000000000003',
  null,
  (select v from t where k='korogwe'),
  1200, 'bajaj',
  st_setsrid(st_makepoint(39.1995, -6.7655), 4326)::geography
);

select pg_temp.check(
  'a passenger outside the corridor is NOT matched',
  (select count(*)::integer from public.match_requests_for_session(
    '99999999-0000-4000-8000-000000000001')),
  1
);

-- ===========================================================================
-- Vehicle type, expiry, seats
-- ===========================================================================

select pg_temp.request(
  'bbbbbbbb-0000-4000-8000-000000000004',
  (select v from t where k='shekilango'),
  (select v from t where k='korogwe'),
  1200, 'boda'
);

select pg_temp.check(
  'a boda request is NOT shown to a bajaj driver',
  (select count(*)::integer from public.match_requests_for_session(
    '99999999-0000-4000-8000-000000000001')),
  1
);

select pg_temp.request(
  'bbbbbbbb-0000-4000-8000-000000000005',
  (select v from t where k='kibo'),
  (select v from t where k='korogwe'),
  1200, 'bajaj', null, now() - interval '1 minute'
);

select pg_temp.check(
  'an expired request is NOT matched',
  (select count(*)::integer from public.match_requests_for_session(
    '99999999-0000-4000-8000-000000000001')),
  1
);

update public.driver_sessions set seats_free = 0
 where id = '99999999-0000-4000-8000-000000000001';
select pg_temp.check(
  'a full vehicle sees nothing',
  (select count(*)::integer from public.match_requests_for_session(
    '99999999-0000-4000-8000-000000000001')),
  0
);
update public.driver_sessions set seats_free = 3
 where id = '99999999-0000-4000-8000-000000000001';

-- ===========================================================================
-- Ordering and distance
-- ===========================================================================

-- Add a nearer passenger at Ubungo Mataa, which is before Shekilango.
insert into t (k, v)
select 'mataa', id from public.stages s
 where s.name = 'Ubungo Mataa' and s.route_id = (select v from t where k='route');

insert into auth.users (id, phone)
values ('bbbbbbbb-0000-4000-8000-000000000006', '+255712000006');
select pg_temp.request(
  'bbbbbbbb-0000-4000-8000-000000000006',
  (select v from t where k='mataa'),
  (select v from t where k='korogwe'),
  -- Deliberately the cheapest offer: ordering must ignore price entirely.
  600
);

select pg_temp.check(
  'nearest ahead is first, never the highest price',
  (select pickup_stage from public.match_requests_for_session(
    '99999999-0000-4000-8000-000000000001') limit 1),
  'Ubungo Mataa'::text
);

select pg_temp.check(
  'distance ahead is measured along the road',
  (select meters_ahead between 700 and 900
     from public.match_requests_for_session('99999999-0000-4000-8000-000000000001')
    where pickup_stage = 'Ubungo Mataa'),
  true
);

-- ===========================================================================
-- Scoping: a driver cannot read another driver's feed
-- ===========================================================================

select set_config('njiani.test_uid', 'bbbbbbbb-0000-4000-8000-000000000001', true);
select pg_temp.check(
  'another user gets an empty feed, not this driver''s',
  (select count(*)::integer from public.match_requests_for_session(
    '99999999-0000-4000-8000-000000000001')),
  0
);

rollback;
