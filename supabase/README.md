# Njiani database

Postgres + PostGIS. The schema is defined entirely by the files in
`migrations/`, which are the **only** source of truth — never change the
database by clicking in Supabase Studio.

## Layout

```
migrations/     numbered SQL, applied in filename order
seed.sql        the pilot corridor: Ubungo <-> Kimara, Morogoro Road
tests/          SQL test suite, run with tests/run.sh
```

## What is in here

| Migration | What it adds |
| --- | --- |
| `…000100_extensions` | PostGIS, pgcrypto |
| `…000200_enums` | vehicle type, driver status, request status, seat state |
| `…000300_reference_data` | routes, stages, price bands |
| `…000400_identity` | profiles, drivers, and the profile-on-signup trigger |
| `…000500_matching_tables` | driver sessions, ride requests, trip seats, ratings |
| `…000600_matching` | **the two functions that are the product** |
| `…000700_rls` | row level security and column privileges |
| `…000800_cron` | expiry, abandoned sessions, position purge |

### The two functions

`match_requests_for_session(session_id)` — the driver feed. A passenger appears
only if they are **(a)** inside the corridor around the road, **(b)** *ahead of
the driver along it*, and **(c)** not stopping past where the driver stops.
(b) is the product: it is why this is PostGIS and not a proximity search.

`accept_ride_request(request_id, session_id)` — the atomic seat claim. Two
drivers tapping Pickup on the same passenger is normal, not an edge case; one
gets `ok` and the other gets `already_taken`, decided by the database rather
than by the UI.

## Running it locally

### Option A — hosted dev project (no Docker; easiest on Windows)

1. Create a free project at supabase.com.
2. Dashboard → Database → Extensions: enable **postgis** and **pg_cron**.
3. Apply the migrations in filename order, then `seed.sql`, via the SQL editor
   — or with the CLI:
   ```sh
   supabase link --project-ref <your-ref>
   supabase db push
   ```
4. Put the URL and anon key in `.env.local` (see `docs/CREDENTIALS.md`).

### Option B — fully local (needs Docker Desktop)

```sh
supabase start          # prints a URL, an anon key, and a db port
supabase db reset       # applies migrations + seed
```

## Running the tests

```sh
DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  ./supabase/tests/run.sh
```

Against a hosted project, use its connection string from
Dashboard → Settings → Database. **Use a dev project, never production** — the
concurrency test writes and deletes rows.

Expected: **47 assertions passed.**

| File | Covers |
| --- | --- |
| `01_matching_test.sql` | ahead-of-me, corridor, past-my-stop, vehicle type, expiry, seats full, ordering, scoping |
| `02_race_*.sql` | two real connections racing one passenger |
| `03_rls_test.sql` | a driver cannot read requests or approve themselves; constraint guards |
| `04_lifecycle_test.sql` | claim, release, re-claim, expiry, stage-mode demand, abandoned sessions |

Everything except the concurrency test runs in a transaction and rolls back.
That one needs two separate connections, so it cleans up after itself.

## ⚠ The coordinates in `seed.sql` are not surveyed

They are plausible positions along Morogoro Road, good enough to develop
against. They are **not** measured.

A stage placed 400 m from where people actually stand falls outside the 300 m
corridor, and the matching query returns nothing while looking perfectly
healthy. That is the worst kind of failure, because there is nothing to see.

Before launch: walk the corridor, take a GPS reading at each stage, and replace
the pairs in `seed.sql`. That same visit is when the price bands get real
numbers instead of the distance-interpolated placeholders.

## Conventions

- **Migrations are append-only.** To change something, add a migration.
- **One route row per direction of travel.** Ubungo→Kimara and Kimara→Ubungo
  are two rows with reversed geometry. That is what makes "ahead of me" a plain
  `>` comparison instead of a heading vector.
- **Drivers never get a read policy on `ride_requests`.** They read matches
  only through their own session. Adding one would undo the security model.
- **The service role key never reaches the apps.** It bypasses all RLS.
