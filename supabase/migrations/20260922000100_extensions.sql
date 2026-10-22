-- Extensions.
--
-- postgis  : the corridor matching in the matching migration is geometry, not
--            proximity. Nothing else in this schema can express "ahead of me
--            along my route".
-- pgcrypto : gen_random_uuid().
--
-- WHERE THESE LIVE, AND WHY IT MATTERS
--
-- Supabase installs extensions into the `extensions` schema, not `public`,
-- and `extensions` is NOT on the default search_path for a migration. A bare
-- `geography(Point, 4326)` therefore fails on a real project with
--
--     ERROR: type "geography" does not exist (SQLSTATE 42704)
--
-- even though it works on a plain Postgres where PostGIS landed in `public`.
-- So every migration and function that touches PostGIS sets its search_path
-- explicitly. Doing it that way rather than schema-qualifying each type keeps
-- the DDL readable and works whichever schema the extension ended up in.

create schema if not exists extensions;

create extension if not exists postgis  with schema extensions;
create extension if not exists pgcrypto with schema extensions;

-- The API roles need to reach the geography type's own functions to read a
-- column that uses it.
grant usage on schema extensions to anon, authenticated, service_role;
