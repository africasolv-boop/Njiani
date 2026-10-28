-- Tests for a passenger's name and optional email.
--
-- Two claims: the parts of a profile a person owns are theirs to change, and
-- the part that is their identity is not.

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

insert into auth.users (id, phone) values
  ('0e000000-0000-4000-8000-000000000001', '+255799000081'),
  ('0e000000-0000-4000-8000-000000000002', '+255799000082');

set local role authenticated;
select set_config('njiani.test_uid', '0e000000-0000-4000-8000-000000000001', true);

-- ---------------------------------------------------------------------------
-- A passenger arrives as nobody, which is the problem this fixes
-- ---------------------------------------------------------------------------
select pg_temp.check(
  'a new profile has no name and no email',
  (select coalesce(display_name, '-') || ' / ' || coalesce(email, '-')
     from public.profiles
    where id = '0e000000-0000-4000-8000-000000000001'),
  '- / -'
);

select pg_temp.check(
  'a passenger can name themselves',
  pg_temp.errcode($sql$
    update public.profiles set display_name = 'Neema Mwinyi'
     where id = '0e000000-0000-4000-8000-000000000001'
  $sql$),
  null
);

-- ---------------------------------------------------------------------------
-- Email: optional, loosely checked, and normalised
-- ---------------------------------------------------------------------------
select pg_temp.check(
  'email stays optional',
  (select email is null from public.profiles
    where id = '0e000000-0000-4000-8000-000000000001'),
  true
);

-- Case and whitespace are not identity. Stored as typed is how one person
-- becomes two rows.
update public.profiles set email = '  NEEMA@Example.COM  '
 where id = '0e000000-0000-4000-8000-000000000001';

select pg_temp.check(
  'email is trimmed and lower-cased',
  (select email from public.profiles
    where id = '0e000000-0000-4000-8000-000000000001'),
  'neema@example.com'
);

select pg_temp.check(
  'a name is trimmed too',
  (select display_name from public.profiles
    where id = '0e000000-0000-4000-8000-000000000001'),
  'Neema Mwinyi'
);

-- Whitespace is not a name. Without this, "   " passes any `is not null`
-- gate the app puts in front of it.
update public.profiles set display_name = '    '
 where id = '0e000000-0000-4000-8000-000000000001';

select pg_temp.check(
  'whitespace is not a name',
  (select display_name is null from public.profiles
    where id = '0e000000-0000-4000-8000-000000000001'),
  true
);

update public.profiles set display_name = 'Neema Mwinyi'
 where id = '0e000000-0000-4000-8000-000000000001';

-- The check is deliberately loose: its job is to catch a typed-in phone
-- number or a stray space, not to adjudicate what an address may contain.
select pg_temp.check(
  'a phone number is not an email',
  pg_temp.errcode($sql$
    update public.profiles set email = '0712345678'
     where id = '0e000000-0000-4000-8000-000000000001'
  $sql$),
  '23514'
);

select pg_temp.check(
  'an address with a space in it is refused',
  pg_temp.errcode($sql$
    update public.profiles set email = 'neema example@mail.com'
     where id = '0e000000-0000-4000-8000-000000000001'
  $sql$),
  '23514'
);

select pg_temp.check(
  'clearing the email is allowed -- it was always optional',
  pg_temp.errcode($sql$
    update public.profiles set email = null
     where id = '0e000000-0000-4000-8000-000000000001'
  $sql$),
  null
);

-- ---------------------------------------------------------------------------
-- What is NOT theirs to change
-- ---------------------------------------------------------------------------

-- The account's identity. Supabase Auth owns it and the trigger copies it in
-- at sign-up; moving it in the app would point a verified session at someone
-- else's number. Same reasoning as the C3 grants on drivers.status.
select pg_temp.check(
  'a passenger cannot change their own phone number',
  pg_temp.errcode($sql$
    update public.profiles set phone = '255700000000'
     where id = '0e000000-0000-4000-8000-000000000001'
  $sql$),
  '42501'
);

with renamed as (
  update public.profiles set display_name = 'Not Me'
   where id = '0e000000-0000-4000-8000-000000000002'
  returning 1
)
select pg_temp.check(
  'and cannot rename somebody else',
  (select count(*)::integer from renamed),
  0
);

select pg_temp.check(
  'nor read them',
  (select count(*)::integer from public.profiles
    where id = '0e000000-0000-4000-8000-000000000002'),
  0
);

reset role;

select pg_temp.check(
  'the other profile is untouched',
  (select display_name is null from public.profiles
    where id = '0e000000-0000-4000-8000-000000000002'),
  true
);

rollback;
