-- Everything the hosted Supabase project provides before our first migration
-- runs: the roles, the `auth` schema, and `auth.uid()`.
--
-- THIS IS NOT A MIGRATION. Migrations are the only source of schema truth
-- (CLAUDE.md), and Supabase already owns everything in this file. It exists so
-- that `./tool/dev-db.sh` can produce a database the migrations will apply to
-- unchanged -- the same ones, in the same order, as `supabase db push`.
--
-- Keep it minimal and keep it honest. Its whole value is being a faithful
-- stand-in; a convenience added here that Supabase does not have is how the
-- PostGIS-in-`public` bug got certified as passing.

-- ---------------------------------------------------------------------------
-- Roles. Supabase's PostgREST maps an anonymous request to `anon` and a
-- request carrying a valid JWT to `authenticated`; `service_role` bypasses
-- RLS. The RLS tests switch between them with `set local role`.
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end
$$;

grant usage on schema public to anon, authenticated, service_role;
grant anon, authenticated, service_role to postgres;
grant usage on schema extensions to anon, authenticated, service_role;

-- Supabase grants these roles full table privileges and lets RLS do the real
-- work. Without this, a policy that should return zero rows raises
-- `permission denied` instead -- a different outcome, and one that would hide
-- a missing policy rather than reveal it.
alter default privileges in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public
  grant execute on functions to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- auth.users. Only the columns our own schema reads: `id`, which every
-- `profiles` row is keyed to, and `phone`, which the new-user trigger copies.
-- The real table has forty-odd more; adding them here would be inventing
-- production behaviour we cannot see.
-- ---------------------------------------------------------------------------
create schema if not exists auth;

create table if not exists auth.users (
  id         uuid primary key default gen_random_uuid(),
  phone      text unique,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- auth.uid(). On Supabase this reads the `sub` claim of the request's JWT,
-- which PostgREST puts in `request.jwt.claims`.
--
-- THE ONE DELIBERATE DEVIATION IN THIS FILE: it also honours a
-- `njiani.test_uid` GUC, which is how the SQL suite says who it is acting as:
--
--   select set_config('njiani.test_uid', '<uuid>', true);
--
-- There is no way around a deviation here -- impersonation on the real
-- project comes from a signed JWT the suite has no way to mint. The JWT claim
-- is read FIRST so that production's path is the one exercised wherever it is
-- available, and `njiani.test_uid` is never set outside these tests.
--
-- Returning NULL when neither is set is the real behaviour, and the reason an
-- RLS policy denies an unauthenticated request rather than erroring.
-- ---------------------------------------------------------------------------
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(
    coalesce(
      current_setting('request.jwt.claim.sub', true),
      (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'),
      current_setting('njiani.test_uid', true)
    ),
    ''
  )::uuid
$$;

create or replace function auth.role()
returns text
language sql
stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'),
    current_user
  )
$$;

grant usage on schema auth to anon, authenticated, service_role;
grant select on auth.users to service_role;
