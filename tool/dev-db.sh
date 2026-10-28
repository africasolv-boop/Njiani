#!/usr/bin/env bash
# Build a local Postgres that matches the hosted Supabase project closely
# enough for the SQL suite to mean something.
#
# Why this file exists: the first version of this harness installed PostGIS
# into `public`. Supabase installs it into `extensions`. Every migration that
# touched a geography column passed locally and then failed on the real
# project with `type "geography" does not exist`. A stand-in that differs from
# production will eventually certify a bug, so the difference is written down
# here rather than typed out from memory each time.
#
#   ./tool/dev-db.sh              # set up, print the DATABASE_URL to export
#   ./tool/dev-db.sh --reset      # drop and rebuild public, then re-apply
#
# Requires postgresql-16, postgresql-16-postgis-3 and the pg_cron extension
# files. On Debian/Ubuntu:
#   apt-get install -y postgresql-16 postgresql-16-postgis-3 postgresql-16-cron
set -euo pipefail
cd "$(dirname "$0")/.."

PGVER="${PGVER:-16}"
PASS="${DEV_DB_PASSWORD:-postgres}"
URL="postgresql://postgres:${PASS}@127.0.0.1:5432/postgres"

say() { printf '==> %s\n' "$1"; }

# ---------------------------------------------------------------------------
# pg_cron has to be preloaded; it cannot be created on demand like PostGIS.
# ---------------------------------------------------------------------------
CONF="/etc/postgresql/${PGVER}/main/postgresql.conf"
if ! grep -q "^shared_preload_libraries.*pg_cron" "$CONF" 2>/dev/null; then
  say "enabling pg_cron in postgresql.conf"
  printf "\nshared_preload_libraries = 'pg_cron'\ncron.database_name = 'postgres'\n" >> "$CONF"
  pg_ctlcluster "$PGVER" main restart || pg_ctlcluster "$PGVER" main start
else
  pg_isready -q -h 127.0.0.1 -p 5432 || pg_ctlcluster "$PGVER" main start
fi

say "setting the postgres password"
su postgres -c "psql -qc \"alter user postgres password '${PASS}'\"" >/dev/null

export PGPASSWORD="$PASS"

# ---------------------------------------------------------------------------
# Extensions, in the schemas Supabase puts them in. `extensions` is the whole
# point: see the note at the top of this file and supabase/README.md.
# ---------------------------------------------------------------------------
say "extensions (postgis in 'extensions', as on Supabase)"
psql -q "$URL" <<'SQL'
create schema if not exists extensions;
create extension if not exists postgis with schema extensions;
create extension if not exists pg_cron;
alter database postgres set search_path = public, extensions;
SQL

if [ "${1:-}" = "--reset" ]; then
  say "dropping public and auth"
  psql -q "$URL" -c 'drop schema public cascade; create schema public; drop schema if exists auth cascade;'
fi

say "Supabase prelude (roles, auth.users, auth.uid)"
psql -q -v ON_ERROR_STOP=1 "$URL" -f tool/dev-db/supabase-prelude.sql

# ---------------------------------------------------------------------------
# Migrations in filename order, then the seed -- the same order `supabase db
# push` uses.
# ---------------------------------------------------------------------------
# Migrations are not written to be re-runnable -- `create type` has no
# `if not exists` -- so a second plain run would fail on the first one and
# look like a broken migration rather than an already-built database.
if [ "${1:-}" != "--reset" ] \
   && psql -tAq "$URL" -c "select to_regclass('public.drivers') is not null" \
      2>/dev/null | grep -q '^t$'; then
  echo ""
  echo "Already applied. Rebuild from scratch with:"
  echo ""
  echo "    ./tool/dev-db.sh --reset"
  echo ""
  echo "    export DATABASE_URL=\"$URL\""
  echo ""
  exit 0
fi

say "migrations"
for f in supabase/migrations/*.sql; do
  printf '    %s\n' "$(basename "$f")"
  psql -q -v ON_ERROR_STOP=1 "$URL" -f "$f"
done

say "seed"
psql -q -v ON_ERROR_STOP=1 "$URL" -f supabase/seed.sql

echo ""
if [ "${1:-}" != "--reset" ]; then
  echo "NOTE: this applied the migrations on top of what was already here."
  echo "      Run with --reset before trusting a green suite: a migration"
  echo "      that ADDS a parameter to an existing function leaves two"
  echo "      behind, and only a rebuild from scratch shows it."
  echo ""
fi
echo "Ready. The SQL suite runs when DATABASE_URL is set:"
echo ""
echo "    export DATABASE_URL=\"$URL\""
echo "    ./tool/check.sh"
echo ""
