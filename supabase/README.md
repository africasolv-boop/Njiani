# Njiani database

Postgres + PostGIS. The schema is defined entirely by the files in
`migrations/`, which are the **only** source of truth — never change the
database by clicking in Supabase Studio.

## Layout

```
config.toml     CLI project config. `supabase link` and `db push` need it
migrations/     numbered SQL, applied in filename order
functions/      Edge Functions
seed.sql        the pilot corridor: Ubungo <-> Kimara, Morogoro Road
tests/          SQL test suite, run with tests/run.sh
```

## ⚠ PostGIS lives in `extensions`, not `public`

Supabase installs extensions into an `extensions` schema which is **not** on
the default search_path. A bare `geography(Point, 4326)` therefore fails on a
real project:

```
ERROR: type "geography" does not exist (SQLSTATE 42704)
```

…while working perfectly on a plain Postgres where PostGIS landed in `public`.

Every migration, function, seed and test that touches PostGIS begins with:

```sql
set search_path = public, extensions;
```

and `config.toml` sets `extra_search_path` so PostgREST can read a `geography`
column over the API — the same problem, on the other side.

**The local test harness installs PostGIS into `extensions` too**, so it
mirrors a hosted project rather than a convenient one. An earlier version put
it in `public`, which is exactly why this bug reached a real project.

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
| `20261026000100_storage_licences` | the private licence bucket and its policies |
| `20261026000200_driver_review` | `review_driver`, `resubmit_driver_licence`, realtime on `drivers` |

### Storage

One bucket, `licences`, created by `20261026000100_storage_licences.sql`.

**Private.** Reads need a signed URL, and only the owner or an admin has a
policy that permits one. The path is `<uid>/licence.<ext>` — the first folder
segment is the owner, which is what makes "your own object" something an RLS
policy can express; `storage.foldername(name)[1]` is how every policy here
matches it. A flat `licence-<uuid>.jpg` would leave nothing to match on.

Storage itself enforces a 5 MB cap and an image-only MIME allow-list, before a
byte is written. The client caps the longest edge at 1600px on the way out,
which is a kindness to a driver's data bundle rather than a limit.

**There is no DELETE policy.** The photo is the evidence behind an approval
decision, so a driver cannot erase it after the fact and an admin cannot do it
by accident from the app. Deletion is a service-role job and belongs with the
retention schedule at C17.

### The two functions

`match_requests_for_session(session_id)` — the driver feed. A passenger appears
only if they are **(a)** inside the corridor around the road, **(b)** *ahead of
the driver along it*, and **(c)** not stopping past where the driver stops.
(b) is the product: it is why this is PostGIS and not a proximity search.

`accept_ride_request(request_id, session_id)` — the atomic seat claim. Two
drivers tapping Pickup on the same passenger is normal, not an edge case; one
gets `ok` and the other gets `already_taken`, decided by the database rather
than by the UI.

### Driver verification (C6)

`drivers.status` is held back from `authenticated` by GRANT, not by RLS — RLS
cannot protect a single column. Two `security definer` functions in
`20261026000200_driver_review.sql` are the only ways it moves:

`review_driver(driver, status, reason)` — the admin decision. Requires an
`admins` row for a signed-in caller; a caller with no JWT is the service role,
which could do this with a plain UPDATE anyway and comes through here for the
checks. **Every rejection needs a reason** — the table has a CHECK that
enforces it, and this raises a sentence a person can read instead of a
constraint name. Stamps `reviewed_at` and `reviewed_by`.

`resubmit_driver_licence(path)` — the one transition a driver may make:
`rejected` → `pending`, with a replaced photo. Scoped to a rejected row, since
a pending driver can already replace the photo with a plain UPDATE. It refuses
a path outside the caller's own folder; without that check a driver could
point their row at another driver's photo and be approved on someone else's
licence.

`drivers` is in the `supabase_realtime` publication, so the pending screen is
told about its own approval. RLS applies to realtime, so a driver is sent
changes to their own row and nobody else's.

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

To run only the SQL suite, without Docker and without the rest of the
Supabase stack, use `./tool/dev-db.sh` — see
[Running the tests](#running-the-tests).

## ⚠ The Providers form demands an SMS provider we never use

Authentication → Providers → Phone has a provider dropdown — Twilio,
MessageBird, Textlocal, Vonage, Twilio Verify — and no "none" or "custom"
entry. Pick any of them and its credential fields turn required, in red. The
form will not save until they are filled.

None of those credentials is ever read. Njiani sends through the **Send SMS
hook** (`supabase/functions/send-sms-hook/`), and when that hook is enabled
Supabase hands the code to it and never touches the configured provider. The
form is validating fields nothing will use.

Two ways through it. Prefer the first.

**Push the config instead of using the form.** `config.toml` in this directory
declares the hook, so:

```sh
supabase link --project-ref <your-ref>
supabase config push
```

The hook, the OTP length, the expiry and the resend window all land from the
file, which is also the record of what they are set to. This is the route the
project is set up for.

**Or save the form with placeholder Twilio credentials.** Any syntactically
plausible values are accepted; nothing validates them against Twilio. This
unblocks the form in a minute.

It carries one risk worth knowing about: the placeholders only stay harmless
while the hook stays enabled. If the hook is ever disabled, or its URL stops
resolving, Supabase falls back to the configured provider — and the failure
surfaces as a Twilio authentication error, which points at a Twilio account
that does not exist rather than at the hook that actually broke. If you take
this route, write in the credential fields themselves that they are unused
(e.g. an Account SID of `unused-send-sms-hook-handles-delivery`) so the next
person reading that error has a chance.

Two other fields in the same form, for the record:

| Field | Set it to | Why |
| --- | --- | --- |
| SMS OTP Length | 6 | Supabase will not go lower. The app's six boxes match it (ARCHITECTURE D19). |
| SMS OTP Expiry | 300s | The 60s default equals our resend window, so a code expires exactly when a new one is offered. |
| SMS Message | *(ignore)* | Unused while the hook is on. Our function composes the message, in both languages. |

## Running the tests

The suite is part of `./tool/check.sh`, but only when `DATABASE_URL` is set —
it needs a real Postgres. Without one the stage prints `SKIPPED` and says so
in the summary line, because a stage that is silently absent reads as a stage
that passed.

### A local database the migrations will apply to

```sh
./tool/dev-db.sh                 # set up and apply migrations + seed
./tool/dev-db.sh --reset         # drop public and auth, rebuild from scratch
```

It prints the `DATABASE_URL` to export. Needs `postgresql-16`,
`postgresql-16-postgis-3` and `postgresql-16-cron`.

The script exists because a plain `createdb` is **not** close enough to
Supabase to test against. Supabase provides, before our first migration runs:

| | and ours needs it because |
| --- | --- |
| PostGIS in the `extensions` schema, not `public` | every geography column; see the warning at the top of this file |
| roles `anon`, `authenticated`, `service_role` | the RLS policies name them |
| full table grants to those roles, with RLS doing the real work | without the grants a policy raises `permission denied` instead of returning zero rows — a different outcome, and one that hides a missing policy |
| `auth.users`, and `auth.uid()` | `profiles.id` is keyed to it, and every policy calls it |
| the `storage` schema, with `buckets`, `objects` and `foldername()` | the licence bucket's policies are rows and RLS on `storage.objects` |

The storage stub covers the policies and nothing else. Nothing local uploads a
byte, signs a URL, or enforces the bucket's size and MIME limits — those live
in the Storage service, not in Postgres. So the policies are tested here and
the upload path is not, and is not claimed to be.

Those live in [`tool/dev-db/supabase-prelude.sql`](../tool/dev-db/supabase-prelude.sql),
which is **not a migration** — Supabase already owns all of it. It has one
deliberate deviation, marked in the file: `auth.uid()` also honours a
`njiani.test_uid` GUC, which is how the suite says who it is acting as. There
is no way around that one; impersonation on the real project comes from a
signed JWT the suite cannot mint. Keep the rest faithful. A convenience added
there that Supabase does not have is how the PostGIS-in-`public` bug came to
be certified as passing.

### Against a hosted project

Use its connection string from Dashboard → Settings → Database. **Use a dev
project, never production** — the concurrency test writes and deletes rows.

Expected: **80 assertions passed.**

| File | Covers |
| --- | --- |
| `01_matching_test.sql` | ahead-of-me, corridor, past-my-stop, vehicle type, expiry, seats full, ordering, scoping |
| `02_race_*.sql` | two real connections racing one passenger |
| `03_rls_test.sql` | a driver cannot read requests or approve themselves; constraint guards |
| `04_lifecycle_test.sql` | claim, release, re-claim, expiry, stage-mode demand, abandoned sessions |
| `05_driver_review_test.sql` | the verification gate: a driver cannot approve themselves, a rejection needs a reason, re-submission keeps the other checks, the column grants, and the bucket's policies |

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
