-- Tests for driver verification: review, re-submission, and the licence
-- bucket's policies. Component C6.
--
-- The claim this file has to hold up is the one the whole gate rests on: a
-- driver can describe their own vehicle, and cannot decide that it has been
-- checked.

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

-- The SQLSTATE a statement failed with, or null if it succeeded.
--
-- Stronger than a boolean "was it refused": these functions raise four
-- different codes for four different reasons, and asserting the code means a
-- test cannot pass because something unrelated broke on the way.
create or replace function pg_temp.errcode(p_sql text)
returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception
  when others then return sqlstate;
end $$;

-- ---------------------------------------------------------------------------
-- Fixtures: two drivers and one admin.
-- ---------------------------------------------------------------------------
insert into auth.users (id, phone) values
  ('f0000000-0000-4000-8000-000000000001', '+255754000031'),  -- driver A
  ('f0000000-0000-4000-8000-000000000002', '+255712000031'),  -- driver B
  ('f0000000-0000-4000-8000-000000000003', '+255713000031');  -- admin

insert into public.admins (profile_id)
values ('f0000000-0000-4000-8000-000000000003');

-- ===========================================================================
-- Act as DRIVER A, applying.
-- ===========================================================================
set local role authenticated;
select set_config('njiani.test_uid', 'f0000000-0000-4000-8000-000000000001', true);

select pg_temp.check(
  'a driver can file their own application',
  pg_temp.errcode($sql$
    insert into public.drivers (profile_id, vehicle_type, plate, colour, licence_path)
    values ('f0000000-0000-4000-8000-000000000001', 'bajaj', 'T 123 ABC', 'Green',
            'f0000000-0000-4000-8000-000000000001/licence.jpg')
  $sql$),
  null
);

select pg_temp.check(
  'a new application starts pending',
  (select status::text from public.drivers
    where profile_id = 'f0000000-0000-4000-8000-000000000001'),
  'pending'
);

-- THE GATE. If this assertion ever goes green-the-other-way, a driver can
-- approve themselves and every other check in this file is decoration.
select pg_temp.check(
  'a driver cannot approve themselves',
  pg_temp.errcode($sql$
    update public.drivers set status = 'approved'
     where profile_id = 'f0000000-0000-4000-8000-000000000001'
  $sql$),
  '42501'
);

select pg_temp.check(
  'a driver cannot file an application for someone else',
  pg_temp.errcode($sql$
    insert into public.drivers (profile_id, vehicle_type, plate, colour)
    values ('f0000000-0000-4000-8000-000000000002', 'boda', 'MC 777 QQ', 'Black')
  $sql$),
  '42501'
);

select pg_temp.check(
  'a driver cannot review anyone',
  pg_temp.errcode($sql$
    select public.review_driver(
      'f0000000-0000-4000-8000-000000000001', 'approved')
  $sql$),
  '42501'
);

-- Why SupabaseDriverRepository does an insert-then-update rather than an
-- upsert. PostgREST writes `on conflict (profile_id) do update set profile_id
-- = excluded.profile_id, ...`, and `profile_id` is not in the C3 update grant.
-- Loosening that grant to cover a primary key, to save one round trip, is the
-- change this assertion exists to stop.
select pg_temp.check(
  'a PostgREST-style upsert is refused, which is why the client does not use one',
  pg_temp.errcode($sql$
    insert into public.drivers (profile_id, vehicle_type, plate, colour, licence_path)
    values ('f0000000-0000-4000-8000-000000000001', 'boda', 'MC 777 QQ', 'Black',
            'f0000000-0000-4000-8000-000000000001/licence.jpg')
    on conflict (profile_id) do update set
      profile_id   = excluded.profile_id,
      vehicle_type = excluded.vehicle_type,
      plate        = excluded.plate,
      colour       = excluded.colour,
      licence_path = excluded.licence_path
  $sql$),
  '42501'
);

select pg_temp.check(
  'the update the client does instead is allowed',
  pg_temp.errcode($sql$
    update public.drivers
       set vehicle_type = 'bajaj', plate = 'T 123 ABC', colour = 'Green'
     where profile_id = 'f0000000-0000-4000-8000-000000000001'
  $sql$),
  null
);

select pg_temp.check(
  'a driver can still correct their own plate',
  pg_temp.errcode($sql$
    update public.drivers set plate = 'T 321 CBA'
     where profile_id = 'f0000000-0000-4000-8000-000000000001'
  $sql$),
  null
);

-- ---------------------------------------------------------------------------
-- The licence bucket.
-- ---------------------------------------------------------------------------
select pg_temp.check(
  'a driver can upload into their own folder',
  pg_temp.errcode($sql$
    insert into storage.objects (bucket_id, name)
    values ('licences', 'f0000000-0000-4000-8000-000000000001/licence.jpg')
  $sql$),
  null
);

select pg_temp.check(
  'a driver cannot upload into someone else''s folder',
  pg_temp.errcode($sql$
    insert into storage.objects (bucket_id, name)
    values ('licences', 'f0000000-0000-4000-8000-000000000002/licence.jpg')
  $sql$),
  '42501'
);

select pg_temp.check(
  'a driver can read back their own photo',
  (select count(*)::integer from storage.objects
    where bucket_id = 'licences'),
  1
);

select pg_temp.check(
  'the bucket is private',
  (select public from storage.buckets where id = 'licences'),
  false
);

-- No DELETE policy, deliberately: the photo is the evidence behind an
-- approval decision, so it does not go away because a driver tapped
-- something. Retention is a service-role job (C17).
with deleted as (
  delete from storage.objects where bucket_id = 'licences' returning 1
)
select pg_temp.check(
  'a driver cannot delete their own photo',
  (select count(*)::integer from deleted),
  0
);

reset role;

-- ===========================================================================
-- Act as the ADMIN.
-- ===========================================================================
set local role authenticated;
select set_config('njiani.test_uid', 'f0000000-0000-4000-8000-000000000003', true);

-- The other half of the bucket's claim: a person has to be able to open the
-- photo, or there is nothing to verify.
select pg_temp.check(
  'an admin can read any licence photo',
  (select count(*)::integer from storage.objects where bucket_id = 'licences'),
  1
);

select pg_temp.check(
  'a rejection with no reason is refused',
  pg_temp.errcode($sql$
    select public.review_driver(
      'f0000000-0000-4000-8000-000000000001', 'rejected')
  $sql$),
  '22023'
);

select pg_temp.check(
  'a rejection with only whitespace is refused',
  pg_temp.errcode($sql$
    select public.review_driver(
      'f0000000-0000-4000-8000-000000000001', 'rejected', '   ')
  $sql$),
  '22023'
);

select pg_temp.check(
  'review_driver will not put a driver back in the queue',
  pg_temp.errcode($sql$
    select public.review_driver(
      'f0000000-0000-4000-8000-000000000001', 'pending')
  $sql$),
  '22023'
);

select pg_temp.check(
  'reviewing an application that does not exist is refused',
  pg_temp.errcode($sql$
    select public.review_driver(
      'f0000000-0000-4000-8000-00000000dead', 'approved')
  $sql$),
  'P0002'
);

select pg_temp.check(
  'an admin can reject, with a reason',
  pg_temp.errcode($sql$
    select public.review_driver(
      'f0000000-0000-4000-8000-000000000001', 'rejected',
      'Glare across the number. Take it again in shade.')
  $sql$),
  null
);

select pg_temp.check(
  'the reason is stored, trimmed',
  (select rejection_reason from public.drivers
    where profile_id = 'f0000000-0000-4000-8000-000000000001'),
  'Glare across the number. Take it again in shade.'
);

select pg_temp.check(
  'the review is stamped with who decided it',
  (select reviewed_by::text from public.drivers
    where profile_id = 'f0000000-0000-4000-8000-000000000001'),
  'f0000000-0000-4000-8000-000000000003'
);

reset role;

-- ===========================================================================
-- Act as DRIVER A again, re-submitting.
-- ===========================================================================
set local role authenticated;
select set_config('njiani.test_uid', 'f0000000-0000-4000-8000-000000000001', true);

select pg_temp.check(
  'a licence path in someone else''s folder is refused',
  pg_temp.errcode($sql$
    select public.resubmit_driver_licence(
      'f0000000-0000-4000-8000-000000000002/licence.jpg')
  $sql$),
  '42501'
);

select pg_temp.check(
  'an empty licence path is refused',
  pg_temp.errcode($sql$ select public.resubmit_driver_licence('  ') $sql$),
  '22023'
);

select pg_temp.check(
  're-submitting returns to pending',
  (select public.resubmit_driver_licence(
     'f0000000-0000-4000-8000-000000000001/licence-2.jpg')::text),
  'pending'
);

select pg_temp.check(
  'the rejection reason is cleared',
  (select rejection_reason is null and reviewed_at is null
     from public.drivers
    where profile_id = 'f0000000-0000-4000-8000-000000000001'),
  true
);

-- "Re-submission does not reset the other checks" -- the design is explicit,
-- because a driver who has to retype a plate at a stage will not finish.
select pg_temp.check(
  'the vehicle details survive a re-submission',
  (select plate || ' / ' || colour || ' / ' || vehicle_type::text
     from public.drivers
    where profile_id = 'f0000000-0000-4000-8000-000000000001'),
  'T 321 CBA / Green / bajaj'
);

select pg_temp.check(
  're-submitting twice is refused -- the row is pending now',
  pg_temp.errcode($sql$
    select public.resubmit_driver_licence(
      'f0000000-0000-4000-8000-000000000001/licence-3.jpg')
  $sql$),
  'P0002'
);

reset role;

-- ===========================================================================
-- Act as DRIVER B, who has no business seeing A's licence.
-- ===========================================================================
set local role authenticated;
select set_config('njiani.test_uid', 'f0000000-0000-4000-8000-000000000002', true);

select pg_temp.check(
  'another driver cannot see the photo',
  (select count(*)::integer from storage.objects where bucket_id = 'licences'),
  0
);

select pg_temp.check(
  'another driver cannot see the application',
  (select count(*)::integer from public.drivers),
  0
);

reset role;

-- ===========================================================================
-- Approval needs a licence on file.
-- ===========================================================================
insert into public.drivers (profile_id, vehicle_type, plate, colour)
values ('f0000000-0000-4000-8000-000000000002', 'boda', 'MC 777 QQ', 'Black');

set local role authenticated;
select set_config('njiani.test_uid', 'f0000000-0000-4000-8000-000000000003', true);

select pg_temp.check(
  'a driver with no licence photo cannot be approved',
  pg_temp.errcode($sql$
    select public.review_driver(
      'f0000000-0000-4000-8000-000000000002', 'approved')
  $sql$),
  '23514'
);

select pg_temp.check(
  'a driver with a licence photo can be',
  pg_temp.errcode($sql$
    select public.review_driver(
      'f0000000-0000-4000-8000-000000000001', 'approved')
  $sql$),
  null
);

select pg_temp.check(
  'an approval clears nothing it should keep',
  (select status::text || ' / ' || licence_path
     from public.drivers
    where profile_id = 'f0000000-0000-4000-8000-000000000001'),
  'approved / f0000000-0000-4000-8000-000000000001/licence-2.jpg'
);

reset role;

-- ===========================================================================
-- Live status: the pending screen cannot subscribe to a table that is not
-- published, and a driver who has to reinstall to find out they were approved
-- is the failure the design names.
-- ===========================================================================
select pg_temp.check(
  'drivers is published for realtime',
  (select count(*)::integer from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'drivers'),
  1
);

rollback;
