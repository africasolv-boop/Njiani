#!/usr/bin/env bash
#
# Runs the SQL test suite against a Postgres database.
#
#   ./supabase/tests/run.sh                       # uses $DATABASE_URL
#   DATABASE_URL=postgresql://... ./supabase/tests/run.sh
#
# With the Supabase CLI (needs Docker):
#   supabase start
#   DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
#     ./supabase/tests/run.sh
#
# Every test runs inside a transaction and rolls back, so the database is left
# exactly as it was found -- except the concurrency test, which cannot roll
# back because its two racing sessions are separate connections. It cleans up
# after itself instead.
set -uo pipefail
cd "$(dirname "$0")/../.."

DB="${DATABASE_URL:-}"
if [ -z "$DB" ]; then
  echo "Set DATABASE_URL first. See the header of this script." >&2
  exit 2
fi

# Runs one file. Fails on a non-zero psql exit as well as on an assertion,
# because a connection refusal is not a passing test.
run() {
  psql "$DB" -X -q -v ON_ERROR_STOP=1 -f "$1" 2>&1
  return "${PIPESTATUS[0]:-$?}"
}

failed=0
total=0

# Reports one file's result.
#
# Zero assertions is a FAILURE, not a pass. An empty run means the file never
# executed -- a dropped connection, a missing database, a typo in a path --
# and reporting that as green is worse than having no suite at all. This
# harness did exactly that once, when psql's lowercase "psql: error:" slipped
# past a grep looking for "ERROR".
report() {
  local name="$1" out="$2" status="$3"
  local passed errors
  passed=$(printf '%s' "$out" | grep -cE 'NOTICE:  ok ')
  errors=$(printf '%s' "$out" | grep -iE 'FAIL|ERROR' | head -3)

  total=$((total + passed))

  if [ "$status" -ne 0 ] || [ -n "$errors" ]; then
    echo "✗ $name — $passed passed, then:"
    [ -n "$errors" ] && printf '%s\n' "$errors" | sed 's/^/    /'
    [ "$status" -ne 0 ] && echo "    psql exited $status"
    failed=1
  elif [ "$passed" -eq 0 ]; then
    echo "✗ $name — ran, but asserted nothing. The file did not execute."
    printf '%s\n' "$out" | head -3 | sed 's/^/    /'
    failed=1
  else
    echo "✓ $name — $passed assertions"
  fi
}

# Every *_test.sql file, rather than a list of numbers. The race files are
# named 02_race_* and are driven by hand below, so they fall outside this
# glob on purpose -- and a new test file is picked up by existing, instead of
# being silently left out until someone notices the assertion count did not
# move.
for f in supabase/tests/*_test.sql; do
  name=$(basename "$f" .sql)
  out=$(run "$f") && status=0 || status=$?
  report "$name" "$out" "$status"
done

# ---------------------------------------------------------------------------
# Concurrency. Two separate connections claim the same passenger at the same
# moment; exactly one must win. This cannot be done inside one transaction,
# which is the entire point of it.
# ---------------------------------------------------------------------------
echo "→ 02_race — two drivers, one passenger"
if ! run supabase/tests/02_race_setup.sql >/dev/null; then
  echo "✗ 02_race — fixtures could not be created" >&2
  exit 1
fi

psql "$DB" -X -q -t -A \
  -v driver=cccccccc-0000-4000-8000-000000000001 \
  -v session=11111111-0000-4000-8000-000000000001 \
  -v hold=2 -f supabase/tests/02_race_claim.sql > /tmp/njiani_race_a.txt 2>&1 &
sleep 0.3
psql "$DB" -X -q -t -A \
  -v driver=cccccccc-0000-4000-8000-000000000002 \
  -v session=11111111-0000-4000-8000-000000000002 \
  -v hold=0 -f supabase/tests/02_race_claim.sql > /tmp/njiani_race_b.txt 2>&1 &
wait

a=$(grep -oE '^[tf]\|[a-z_]+' /tmp/njiani_race_a.txt | head -1)
b=$(grep -oE '^[tf]\|[a-z_]+' /tmp/njiani_race_b.txt | head -1)
echo "    driver A: ${a:-no result}"
echo "    driver B: ${b:-no result}"

out=$(run supabase/tests/02_race_verify.sql) && status=0 || status=$?
report "02_race" "$out" "$status"

# Leave no fixtures behind.
run supabase/tests/02_race_cleanup.sql >/dev/null

echo ""
if [ "$failed" -eq 0 ]; then
  echo "All $total SQL assertions passed."
else
  echo "SQL tests failed." >&2
fi
exit "$failed"
