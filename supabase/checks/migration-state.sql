-- Why does `supabase db push` want to re-apply migrations that already ran?
--
-- Because two separate things have to agree, and only one of them is the
-- schema:
--
--   1. the objects in the database;
--   2. `supabase_migrations.schema_migrations`, the CLI's record of which
--      files it has applied.
--
-- Applying the SQL any other way -- pasting it into the Studio SQL editor, a
-- `psql -f`, restoring a dump -- creates the objects and writes nothing to
-- (2). The next `db push` therefore replays everything from the top and dies
-- on the first statement that is not idempotent:
--
--     ERROR: type "vehicle_type" already exists (SQLSTATE 42710)
--
-- That error means the history is behind, NOT that the migration is broken.
--
-- Paste this whole file into the Supabase SQL editor (or run it with psql).
-- It reads nothing but catalogues, writes nothing, and prints a verdict per
-- migration plus the exact command to fix it.
--
-- It is meant for a hosted project. Pointed at a database built by
-- `tool/dev-db.sh` it will report every migration as needing repair, which is
-- true and uninteresting: that script applies the files directly and the CLI
-- has never seen it.

do $$
declare
  history_exists boolean :=
    to_regclass('supabase_migrations.schema_migrations') is not null;
  recorded text[] := '{}';
begin
  if history_exists then
    execute 'select coalesce(array_agg(version), ''{}'') '
            'from supabase_migrations.schema_migrations'
      into recorded;
  end if;

  -- Session-scoped, not transaction-scoped: in the SQL editor and under
  -- psql's autocommit this block commits before the SELECT at the bottom
  -- runs, and `on commit drop` would take the table with it.
  drop table if exists njiani_migration_state;
  create temporary table njiani_migration_state (
    seq       integer,
    migration text,
    objects   text,
    recorded  text,
    verdict   text
  );

  -- One probe per migration: an object that migration and only that
  -- migration creates. Catalogue lookups, so this works on a database the
  -- CLI has never touched.
  insert into njiani_migration_state (seq, migration, objects, recorded, verdict)
  select
    v.seq,
    v.version || '_' || v.name,
    case when v.present then 'present' else 'MISSING' end,
    case
      when not history_exists then 'no history table'
      when v.version = any (recorded) then 'recorded'
      else 'NOT RECORDED'
    end,
    case
      when v.present and not history_exists then 'repair: mark applied'
      when v.present and v.version = any (recorded) then 'ok'
      when v.present then 'repair: mark applied'
      when not v.present and history_exists and v.version = any (recorded)
        then 'RECORDED BUT MISSING -- see the note at the bottom'
      else 'will be applied by db push'
    end
  from (values
    (1, '20260922000100', 'extensions',
     exists (select 1 from pg_extension where extname = 'postgis')),
    (2, '20260922000200', 'enums',
     to_regtype('public.vehicle_type') is not null),
    (3, '20260922000300', 'reference_data',
     to_regclass('public.routes') is not null),
    (4, '20260922000400', 'identity',
     to_regclass('public.drivers') is not null),
    (5, '20260922000500', 'matching_tables',
     to_regclass('public.trip_seats') is not null),
    (6, '20260922000600', 'matching',
     exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public'
                and p.proname = 'match_requests_for_session')),
    (7, '20260922000700', 'rls',
     exists (select 1 from pg_policies
              where schemaname = 'public' and tablename = 'drivers'
                and policyname = 'drivers_read_own')),
    (8, '20260922000800', 'cron',
     exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public'
                and p.proname = 'close_abandoned_sessions')),
    (9, '20261026000100', 'storage_licences',
     exists (select 1 from storage.buckets where id = 'licences')),
    (10, '20261026000200', 'driver_review',
     exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public' and p.proname = 'review_driver'))
  ) as v(seq, version, name, present);

  -- The command to run, built from what is actually here.
  insert into njiani_migration_state (seq, migration, objects, recorded, verdict)
  select
    999,
    'RUN THIS',
    '',
    '',
    case
      when count(*) = 0
        then 'Nothing to repair. `supabase db push` will apply what is left.'
      else 'npx supabase migration repair --status applied '
           || string_agg(split_part(migration, '_', 1), ' ' order by seq)
           || '   # then: npx supabase db push'
    end
  from njiani_migration_state
  where verdict = 'repair: mark applied';
end
$$;

select migration, objects, recorded, verdict
from njiani_migration_state
order by seq;

-- RECORDED BUT MISSING means the opposite problem: the CLI thinks a migration
-- ran and its objects are not there. That is real drift, not a bookkeeping
-- gap, and marking anything applied would bury it. Say so rather than
-- repairing -- on a dev project the honest fix is usually to reset the
-- database and push from scratch.
