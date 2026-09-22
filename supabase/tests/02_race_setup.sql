-- Fixtures for the concurrency test. Committed, because the two racing
-- sessions are separate connections and must see the same rows.
\set ON_ERROR_STOP on

delete from public.trip_seats;
delete from public.ride_requests;
delete from public.driver_sessions;
delete from public.drivers;
delete from public.profiles where id::text like 'cccccccc%' or id::text like 'dddddddd%';
delete from auth.users where id::text like 'cccccccc%' or id::text like 'dddddddd%';

-- Two DIFFERENT drivers. This is the real race: they lock different session
-- rows, so the only contention is on the request itself.
insert into auth.users (id, phone) values
  ('cccccccc-0000-4000-8000-000000000001', '+255754000011'),
  ('cccccccc-0000-4000-8000-000000000002', '+255754000012'),
  ('dddddddd-0000-4000-8000-000000000001', '+255712000011');

insert into public.drivers (profile_id, vehicle_type, plate, colour, licence_path, status)
values
  ('cccccccc-0000-4000-8000-000000000001', 'bajaj', 'T 111 AAA', 'Blue', 'l/1.jpg', 'approved'),
  ('cccccccc-0000-4000-8000-000000000002', 'bajaj', 'T 222 BBB', 'Red',  'l/2.jpg', 'approved');

insert into public.driver_sessions
  (id, driver_id, route_id, dest_stage_id, vehicle_type, seats_total, seats_free, last_pos, last_pos_at)
select
  ('11111111-0000-4000-8000-00000000000' || n)::uuid,
  ('cccccccc-0000-4000-8000-00000000000' || n)::uuid,
  r.id,
  (select id from public.stages where route_id = r.id and name = 'Kimara Korogwe'),
  'bajaj', 3, 3,
  (select geom from public.stages where route_id = r.id and name = 'Ubungo Bus Terminal'),
  now()
from public.routes r, generate_series(1, 2) n
where r.direction_label = 'Westbound';

insert into public.ride_requests
  (id, passenger_id, route_id, pickup, pickup_stage_id, dest_stage_id,
   vehicle_type, offer_price)
select
  '22222222-0000-4000-8000-000000000001',
  'dddddddd-0000-4000-8000-000000000001',
  r.id,
  (select geom from public.stages where route_id = r.id and name = 'Shekilango'),
  (select id   from public.stages where route_id = r.id and name = 'Shekilango'),
  (select id   from public.stages where route_id = r.id and name = 'Kimara Korogwe'),
  'bajaj', 1500
from public.routes r where r.direction_label = 'Westbound';
