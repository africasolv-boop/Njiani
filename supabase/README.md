# Njiani database

Postgres + PostGIS. The schema is defined entirely by the files in
`migrations/`, which are the **only** source of truth — never change the
database by clicking in Supabase Studio.

## Layout

```
config.toml     CLI project config. `supabase link` and `db push` need it
checks/         diagnostics you paste into the SQL editor, read-only
dev/            development fixtures that WRITE. Never run automatically.
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
| `20261027000100_going_online` | `seats_for`, `destinations_ahead`, `go_online`, `go_offline`, `report_position` |
| `20261028000100_feed_nudge` | the feed's realtime nudge, `current_driver_session`, and a driver no longer seeing their own request |

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

### Going online (C7)

`driver_sessions` is not a table a driver writes. `insert` and `update` are
revoked from `authenticated` apart from `last_pos` and `last_pos_at`, and
everything structural goes through
`20261027000100_going_online.sql`:

`go_online(route, dest, pos, from_stage)` — ends any session already open and
starts a new one, which is also how changing direction works;
`driver_sessions_one_online_idx` makes being online twice impossible, so there
is no second path. It enforces the C6 approval gate, reads `vehicle_type` and
`seats_total` from the driver's own row, refuses a destination that is not a
stage on the declared route, and opens with the seats that are genuinely free
— a driver changing direction mid-trip keeps the passengers already with them,
and the new session must not sell those seats again.

`go_offline()` — ends the session and nothing else. A claimed seat is a
passenger who is waiting or already aboard, and closing an app is not a
cancellation; that is `release_trip_seat`, a separate deliberate act.

`destinations_ahead(point)` and `destinations_from_stage(stage)` — the
destination list, and the directional logic in miniature. A stage counts only
if it is further along the route than the driver, by the same
`ST_LineLocatePoint` fraction the matching query uses. That is also what picks
the direction: a point on this corridor sits in both routes' corridors, but
any given stage is ahead on exactly one of them.

`report_position(point)` — the one thing about a session a client writes, and
the only reason `last_pos` is still in the update grant.

### Keeping a feed live (C9)

A feed cannot be a subscription to `ride_requests`: Realtime respects RLS and
a driver holds no read policy on that table. So the signal and the data are
split.

`notify_route_of_request()` fires on a request appearing, or leaving `open`,
and broadcasts to `route_feed_topic(route_id, vehicle_type)` — a payload of a
route id, a vehicle type and a timestamp, and nothing else. The client answers
it by calling `match_requests_for_session()`, which applies the same scoping
it always did. **The live part is a doorbell, not a window.**

The topic name is computed by `route_feed_topic()` in SQL and by
`SupabaseFeedRepository.topicFor()` in Dart. A mismatch is a feed that is
silently never live, so there is an assertion on each side pinning the format.

The trigger is **best effort, deliberately**: its whole body is wrapped, so an
outage, a renamed function or a missing schema cannot stop a passenger's
request being written. The client polls every 30 seconds alongside it, which
is what recovers from a socket that died in a tunnel. A dropped nudge costs
latency and nothing else.

Subscription is gated by a policy on `realtime.messages`: a driver may listen
to a route's topic only while they are online on that route, in that vehicle.
It expires with the session, which is the lifetime the feed has.

### Putting something in a feed by hand

`dev/fake-request.sql` writes a request that looks like real passenger
traffic, and prints why each online driver can or cannot see it. Needed until
C8 builds the passenger's side, and useful after it for testing a feed
without a second phone. `dev/fake-request-cleanup.sql` removes everything it
made.

Both are scoped to a `0de00de0-` id prefix, which no migration, seed or test
uses — `dddddddd-` would have been deleted by the concurrency test's own
cleanup.

## Running it locally

### Option A — hosted dev project (no Docker; easiest on Windows)

1. Create a free project at supabase.com.
2. Dashboard → Database → Extensions: enable **postgis** and **pg_cron**.
3. Apply the migrations **with the CLI**:
   ```sh
   supabase link --project-ref <your-ref>
   supabase db push
   ```
4. Run `seed.sql` in the SQL editor. It is reference data, not schema, so it
   is not a migration and `db push` does not run it.
5. Put the URL and anon key in `.env.local` (see `docs/CREDENTIALS.md`).

> **Use `db push`, not the SQL editor, for the migrations.** An earlier
> version of this file offered the SQL editor as an equal alternative. It is
> not: pasting the files in creates every object and tells the CLI nothing, so
> the next `db push` replays all of them from the top and dies on the first
> statement that cannot run twice. The section below is how to get out of
> that.

### Option B — fully local (needs Docker Desktop)

```sh
supabase start          # prints a URL, an anon key, and a db port
supabase db reset       # applies migrations + seed
```

To run only the SQL suite, without Docker and without the rest of the
Supabase stack, use `./tool/dev-db.sh` — see
[Running the tests](#running-the-tests).

## ⚠ `db push` wants to re-apply migrations that already ran

```
Applying migration 20260922000200_enums.sql...
ERROR: type "vehicle_type" already exists (SQLSTATE 42710)
```

**The migration is not broken and the database is not broken.** Two separate
things have to agree, and only one of them is the schema:

1. the objects in the database;
2. `supabase_migrations.schema_migrations`, the CLI's record of which files it
   has applied.

Anything that creates the objects without going through `db push` — the
Studio SQL editor, a `psql -f`, a restored dump — leaves (2) empty. The next
push then starts from the first file and stops at the first statement that
cannot run twice, which is `create type` in `…000200_enums`.

### Fixing it

```sh
psql "$DATABASE_URL" -f supabase/checks/migration-state.sql
```

…or paste [`checks/migration-state.sql`](checks/migration-state.sql) into the
SQL editor. It reads only catalogues, writes nothing, and prints a verdict per
migration — plus the exact command to run, built from what is actually there:

```
 20260922000200_enums  | present | NOT RECORDED | repair: mark applied
 20261026000100_…      | MISSING | NOT RECORDED | will be applied by db push
 RUN THIS              |         |              | npx supabase migration repair --status applied …
```

`migration repair --status applied` writes the history rows without running
the SQL. Then `db push` applies only what is genuinely left.

### What not to do

**Do not make the migrations idempotent to get the push through.** `create
type … if not exists` would make the error go away and leave the history
still wrong, so the next real migration lands on a database nobody can
describe. The error is doing its job; the history is what needs fixing.

One verdict means the opposite problem. **RECORDED BUT MISSING** — the CLI
thinks a file ran and its objects are not there — is real drift, and marking
it applied would bury it. On a dev project the honest fix is
`supabase db reset` (local) or recreating the project and pushing from
scratch.

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

Expected: **130 assertions passed.**

| File | Covers |
| --- | --- |
| `01_matching_test.sql` | ahead-of-me, corridor, past-my-stop, vehicle type, expiry, seats full, ordering, scoping |
| `02_race_*.sql` | two real connections racing one passenger |
| `03_rls_test.sql` | a driver cannot read requests or approve themselves; constraint guards |
| `04_lifecycle_test.sql` | claim, release, re-claim, expiry, stage-mode demand, abandoned sessions |
| `05_driver_review_test.sql` | the verification gate: a driver cannot approve themselves, a rejection needs a reason, re-submission keeps the other checks, the column grants, and the bucket's policies |
| `06_going_online_test.sql` | what is ahead and what is behind, a session built from the driver's record rather than the client's, and a claimed seat surviving a direction change without being sold twice |
| `07_feed_nudge_test.sql` | the nudge carries nothing a driver may not read, a broken broadcast does not stop a request, who may subscribe, and nearest-ahead ordering beating a better offer |

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
