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

run() { psql "$DB" -X -q -v ON_ERROR_STOP=1 -f "$1" 2>&1; }

failed=0
total=0

for f in supabase/tests/0[134]*_test.sql; do
  name=$(basename "$f" .sql)
  out=$(run "$f")
  passed=$(printf '%s' "$out" | grep -cE 'NOTICE:  ok ')
  errors=$(printf '%s' "$out" | grep -E 'FAIL|ERROR' | head -3)
  total=$((total + passed))
  if [ -n "$errors" ]; then
    echo "✗ $name — $passed passed, then:"
    printf '%s\n' "$errors" | sed 's/^/    /'
    failed=1
  else
    echo "✓ $name — $passed assertions"
  fi
done

# ---------------------------------------------------------------------------
# Concurrency. Two separate connections claim the same passenger at the same
# moment; exactly one must win. This cannot be done inside one transaction,
# which is the entire point of it.
# ---------------------------------------------------------------------------
echo "→ 02_race — two drivers, one passenger"
run supabase/tests/02_race_setup.sql >/dev/null

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

out=$(run supabase/tests/02_race_verify.sql)
passed=$(printf '%s' "$out" | grep -cE 'NOTICE:  ok ')
errors=$(printf '%s' "$out" | grep -E 'FAIL|ERROR' | head -3)
total=$((total + passed))
if [ -n "$errors" ]; then
  echo "✗ 02_race — $passed passed, then:"
  printf '%s\n' "$errors" | sed 's/^/    /'
  failed=1
else
  echo "✓ 02_race — $passed assertions"
fi

# Leave no fixtures behind.
run supabase/tests/02_race_cleanup.sql >/dev/null

echo ""
if [ "$failed" -eq 0 ]; then
  echo "All $total SQL assertions passed."
else
  echo "SQL tests failed." >&2
fi
exit "$failed"
