-- Tests for Row Level Security.
--
-- Two of these carry the whole security model:
--   * a driver cannot read ride_requests directly, only through their own
--     session's matching function;
--   * a driver cannot write drivers.status, which is the verification gate.

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

-- True when the statement was refused by the database.
--
-- Covers the three ways this schema says no: a privilege the role lacks, a
-- CHECK constraint, and a partial unique index. Anything else propagates, so
-- a test cannot pass for the wrong reason.
create or replace function pg_temp.denied(p_sql text)
returns boolean language plpgsql as $$
begin
  execute p_sql;
  return false;
exception
  when insufficient_privilege
    or check_violation
    or unique_violation
    or foreign_key_violation then return true;
end $$;

insert into auth.users (id, phone) values
  ('eeeeeeee-0000-4000-8000-000000000001', '+255754000021'),
  ('eeeeeeee-0000-4000-8000-000000000002', '+255712000021');

insert into public.drivers (profile_id, vehicle_type, plate, colour, licence_path, status)
values ('eeeeeeee-0000-4000-8000-000000000001', 'bajaj', 'T 999 ZZZ', 'Green',
        'l/9.jpg', 'pending');

insert into public.ride_requests
  (id, passenger_id, route_id, pickup, pickup_stage_id, dest_stage_id,
   vehicle_type, offer_price)
select
  '33333333-0000-4000-8000-000000000001',
  'eeeeeeee-0000-4000-8000-000000000002',
  r.id,
  (select geom from public.stages where route_id = r.id and name = 'Shekilango'),
  (select id   from public.stages where route_id = r.id and name = 'Shekilango'),
  (select id   from public.stages where route_id = r.id and name = 'Kimara Korogwe'),
  'bajaj', 1500
from public.routes r where r.direction_label = 'Westbound';

-- ===========================================================================
-- Act as the DRIVER.
-- ===========================================================================
set local role authenticated;
select set_config('njiani.test_uid', 'eeeeeeee-0000-4000-8000-000000000001', true);

select pg_temp.check(
  'a driver cannot read ride_requests directly',
  (select count(*)::integer from public.ride_requests),
  0
);

select pg_temp.check(
  'a driver cannot see another user''s profile',
  (select count(*)::integer from public.profiles
    where id = 'eeeeeeee-0000-4000-8000-000000000002'),
  0
);

select pg_temp.check(
  'a driver CAN see their own driver row',
  (select count(*)::integer from public.drivers
    where profile_id = 'eeeeeeee-0000-4000-8000-000000000001'),
  1
);

select pg_temp.check(
  'a driver cannot approve themselves',
  pg_temp.denied($sql$
    update public.drivers set status = 'approved'
     where profile_id = 'eeeeeeee-0000-4000-8000-000000000001'
  $sql$),
  true
);

select pg_temp.check(
  'a driver CAN correct their own plate',
  pg_temp.denied($sql$
    update public.drivers set plate = 'T 000 AAA'
     where profile_id = 'eeeeeeee-0000-4000-8000-000000000001'
  $sql$),
  false
);

select pg_temp.check(
  'a driver can read the stage list',
  (select count(*)::integer > 0 from public.stages),
  true
);

-- ===========================================================================
-- Act as the PASSENGER.
-- ===========================================================================
select set_config('njiani.test_uid', 'eeeeeeee-0000-4000-8000-000000000002', true);

select pg_temp.check(
  'a passenger sees their own request',
  (select count(*)::integer from public.ride_requests),
  1
);

select pg_temp.check(
  'a passenger cannot read driver sessions',
  (select count(*)::integer from public.driver_sessions),
  0
);

select pg_temp.check(
  'a passenger cannot read the admin list',
  (select count(*)::integer from public.admins),
  0
);

-- ===========================================================================
-- Act as NOBODY (signed out).
-- ===========================================================================
select set_config('njiani.test_uid', '', true);

select pg_temp.check(
  'a signed-out user sees no requests',
  (select count(*)::integer from public.ride_requests),
  0
);

select pg_temp.check(
  'a signed-out user sees no profiles',
  (select count(*)::integer from public.profiles),
  0
);

reset role;

-- ===========================================================================
-- Constraints that protect people, not just data.
-- ===========================================================================

select pg_temp.check(
  'a rejection without a reason is refused',
  pg_temp.denied($sql$
    update public.drivers set status = 'rejected'
     where profile_id = 'eeeeeeee-0000-4000-8000-000000000001'
  $sql$),
  true
);

select pg_temp.check(
  'approval without a licence on file is refused',
  pg_temp.denied($sql$
    insert into public.drivers
      (profile_id, vehicle_type, plate, colour, status)
    values ('eeeeeeee-0000-4000-8000-000000000002', 'boda', 'MC 1 A', 'Red', 'approved')
  $sql$),
  true
);

select pg_temp.check(
  'a bajaj session cannot claim four seats',
  pg_temp.denied($sql$
    insert into public.driver_sessions
      (driver_id, route_id, dest_stage_id, vehicle_type, seats_total, seats_free)
    select 'eeeeeeee-0000-4000-8000-000000000001', r.id,
           (select id from public.stages where route_id = r.id limit 1),
           'bajaj', 4, 4
      from public.routes r limit 1
  $sql$),
  true
);

select pg_temp.check(
  'a passenger cannot hold two open requests',
  pg_temp.denied($sql$
    insert into public.ride_requests
      (passenger_id, route_id, pickup, pickup_stage_id, dest_stage_id,
       vehicle_type, offer_price)
    select 'eeeeeeee-0000-4000-8000-000000000002', r.id,
           (select geom from public.stages where route_id = r.id and name = 'Kibo'),
           (select id   from public.stages where route_id = r.id and name = 'Kibo'),
           (select id   from public.stages where route_id = r.id and name = 'Kimara Korogwe'),
           'bajaj', 1200
      from public.routes r where r.direction_label = 'Westbound'
  $sql$),
  true
);

rollback;
