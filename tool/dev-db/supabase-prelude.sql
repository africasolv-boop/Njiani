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

-- ---------------------------------------------------------------------------
-- storage. Supabase Storage keeps its bucket registry and object index in a
-- `storage` schema, and bucket access is expressed as RLS policies on
-- `storage.objects`. C6's licence bucket needs both to exist before its
-- migration will apply.
--
-- Only what our policies touch: `buckets`, `objects`, and `foldername()`,
-- which is how "the first folder segment is the owner" becomes something a
-- policy can say. The real tables carry a dozen more columns each and the
-- real schema a dozen more functions; none of them appear in our SQL.
--
-- What this CANNOT stand in for: the storage API itself. Nothing here uploads
-- a byte, signs a URL, or enforces the bucket's size and MIME limits -- those
-- live in the Storage service, not in Postgres. The policies below are
-- testable here; the upload path is not, and is not claimed to be.
-- ---------------------------------------------------------------------------
create schema if not exists storage;

create table if not exists storage.buckets (
  id                 text primary key,
  name               text not null unique,
  owner              uuid,
  public             boolean not null default false,
  file_size_limit    bigint,
  allowed_mime_types text[],
  created_at         timestamptz not null default now()
);

create table if not exists storage.objects (
  id         uuid primary key default gen_random_uuid(),
  bucket_id  text references storage.buckets (id),
  name       text,
  owner      uuid,
  metadata   jsonb,
  created_at timestamptz not null default now(),
  unique (bucket_id, name)
);

alter table storage.objects enable row level security;

-- Splits a path and drops the filename, so `<uid>/licence.jpg` yields
-- `{<uid>}` and `[1]` is the owner. Matches Supabase's own definition.
create or replace function storage.foldername(name text)
returns text[]
language plpgsql
immutable
as $$
declare
  parts text[];
begin
  select string_to_array(name, '/') into parts;
  return parts[1:array_length(parts, 1) - 1];
end
$$;

grant usage on schema storage to anon, authenticated, service_role;
grant all on storage.buckets, storage.objects
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- realtime. Supabase's Realtime service owns this schema. C9 uses two pieces
-- of it: `realtime.send()`, which a trigger calls to broadcast a nudge, and
-- `realtime.messages`, whose RLS decides who may subscribe to a private
-- topic.
--
-- `send` here RECORDS instead of broadcasting, into `realtime.sent`, so a
-- test can assert that the trigger fired with the right topic and a payload
-- carrying no passenger data. That table is ours, not Supabase's; nothing in
-- `supabase/migrations/` may reference it.
--
-- What this CANNOT stand in for: the Realtime service. Nothing here delivers
-- a message to a client, and nothing here proves that Realtime consults
-- `realtime.messages` RLS the way the policy assumes. What it does prove is
-- that the trigger calls a real signature, with the topic the client
-- computes, and that the policy is valid SQL whose predicate says what it
-- means to say. The delivery itself is tested on a device.
-- ---------------------------------------------------------------------------
create schema if not exists realtime;

-- Every broadcast the trigger attempted, in order.
create table if not exists realtime.sent (
  id          bigserial primary key,
  payload     jsonb,
  event       text,
  topic       text,
  private     boolean,
  inserted_at timestamptz not null default now()
);

-- Matches Supabase's signature, including the argument order and the
-- `private` default. A mismatch here would mean the trigger compiles locally
-- and fails on the real project -- caught by its exception handler, and
-- therefore silent, which is the worst way for it to be wrong.
create or replace function realtime.send(
  payload jsonb,
  event   text,
  topic   text,
  private boolean default true
)
returns void
language sql
as $$
  insert into realtime.sent (payload, event, topic, private)
  values (payload, event, topic, private);
$$;

-- The subscribe gate. Only the columns the C9 policy reads; the real table
-- carries an id, an extension and an inserted_at as well.
create table if not exists realtime.messages (
  topic       text not null,
  extension   text,
  event       text,
  private     boolean default false,
  payload     jsonb,
  inserted_at timestamptz not null default now()
);

alter table realtime.messages enable row level security;

grant usage on schema realtime to anon, authenticated, service_role;
grant all on realtime.messages, realtime.sent to authenticated, service_role;
grant execute on function realtime.send(jsonb, text, text, boolean)
  to authenticated, service_role;
