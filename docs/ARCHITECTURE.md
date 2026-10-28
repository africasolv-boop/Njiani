# Njiani — Master Architecture Document

> **Status:** Planning approved 2026-09-21. No application code written yet.
> **This is the master document.** Every decision lives here. Build progress lives in
> [`BUILD_LOG.md`](./BUILD_LOG.md). Credentials live in [`CREDENTIALS.md`](./CREDENTIALS.md).

---

## 1. What Njiani is

Njiani is **not** a ride-hailing app. It is a **directional seat-filling marketplace** for
bajaj (three-wheelers) and boda boda (motorcycles) in Dar es Salaam.

The inversion that defines the product:

| Ride-hailing (Bolt, Uber) | Njiani |
| --- | --- |
| Passenger names a destination, driver is dispatched there | **Driver declares a heading first**, then sees only passengers going that way |
| One passenger per trip | **Up to 3 passengers per bajaj**, each paying for their own seat |
| Platform sets the price | **Passenger names their own price**, driver accepts or ignores |
| Driver often returns empty | Driver fills seats on a road they were already travelling |

Payment is settled **off-app** between passenger and driver (cash, M-Pesa, Tigo Pesa,
Airtel Money). The app records the agreed amount; it does not move money. See §11.

**Launch scope:** one corridor — Ubungo → Kimara along Morogoro Road — with 15–30
hand-registered drivers.

---

## 2. Decision log

Decisions taken during planning, with the reasoning, so we can revisit them knowingly.

| # | Decision | Chosen | Why |
| --- | --- | --- | --- |
| D1 | Backend | **Supabase** (Postgres 15 + PostGIS + Realtime + RLS + Storage + Edge Functions) | The core query — *"whose pickup is ahead of me along my route?"* — is geometry, not proximity. PostGIS answers it in ~15 lines. Firestore structurally cannot, and would need rewriting at route #2. Also gives race-safe seat claiming via SQL row locks. |
| D2 | Push notifications | **Firebase Cloud Messaging only** | Free, both platforms, no other Firebase service used. |
| D3 | Client framework | **Flutter 3.27+ / Dart 3.6+** floor; built and verified on **Flutter 3.47.5 / Dart 3.13.4** | One codebase → Android + iOS, as the pitch plans. Small binary for low-end driver phones. Dart 3.6 is the floor because we use native pub workspaces. |
| D4 | App packaging | **Two apps from one monorepo** — `Njiani` (rider) and `Njiani Driver` | User's call. Monorepo with a shared `njiani_core` package means two store listings but one design system, one data layer, one set of migrations. |
| D5 | Dev/test machine | **macOS + iPhone + Android device** | Both platforms testable locally from day one. Every component's test steps cover both. |
| D6 | Maps — MVP | **`flutter_map`** behind a `MapAdapter` interface | Pure Dart, no native build config, runs instantly on both simulators. Maps are *display only* until C14 — matching runs on named stages in PostGIS. |
| D7 | Maps — C14 onward | **MapLibre GL + self-hosted Protomaps `.pmtiles`** | User's preferred direction. Tanzania OSM extract → one `.pmtiles` file on Cloudflare R2. Free forever, no API key, no rate limit, works offline. Swaps in behind `MapAdapter`. |
| D8 | Routing / ETA | Haversine ÷ 18 km/h until C14, then **self-hosted OSRM** (Tanzania extract, ~$6/mo VPS) | The public OSRM demo server forbids production use. Self-hosting Tanzania is cheap and removes the dependency. |
| D9 | Geocoding | **None in MVP.** Nominatim or Photon at v2 | Matching uses a fixed list of named stages, so there is nothing to geocode yet. (Note: OSRM does *not* do geocoding — it is a routing engine. Nominatim is the geocoder.) |
| D10 | SMS / OTP | Supabase phone auth + **Send-SMS hook → Beem Africa** | ~TSh 20–30/SMS vs international rates, better local delivery, and a branded `NJIANI` sender ID — which matters when asking a driver at a stage to trust a code. |
| D11 | Payments | **Cash / direct mobile money. App records the amount only.** | No wallet, no escrow, no aggregator licensing. Revisit when the weekly driver fee launches. See §11. |
| D12 | Admin | Supabase Studio + SQL views → Flutter Web admin at C16 | Do not build a dashboard before there is data to put in it. |
| D13 | Error tracking | **Sentry** | Better Flutter stack traces than Crashlytics; generous free tier. |
| D14 | Source of visual truth | **The Claude Design project (`Njiani Apps.dc.html`)**, not the pitch deck | The pitch deck was a prototype, not a design. C1's first pass was built from its CSS and did not land. The design project supersedes it for every visual decision from here. |
| D15 | Build unit after C1 | **One screen at a time**, not one component at a time | The redesign is organised as screens. Shared components are extracted into `njiani_core` as part of the revised C1, then screens are built on top, one per sign-off. |
| D17 | Localisation | **ARB + `flutter gen-l10n`**, generated output committed and drift-guarded | A fresh clone analyses and tests with no codegen step. `tool/check.sh` regenerates and fails if the result moved, so the committed files cannot go stale. |
| D19 | SMS code length | **6 digits, not the 4 in the design** | Supabase Auth will not issue an SMS code below 6 (range 6–10), so 4 boxes could never be filled by a code it sent. Six is also a million combinations against ten thousand, and the code is the only authentication factor. Held in one constant, `kOtpLength`. |
| D20 | Who verifies the code | **Supabase Auth, never the app and never Beem** | Beem is pure transport. Its hosted OTP product would mean bridging Beem's verdict into a Supabase session by hand, which is home-made auth in a ride-hailing app. |
| D21 | Licence photos | **Private Storage bucket, path `<uid>/licence.<ext>`, no delete policy** | The first folder segment being the owner is what makes "your own object" expressible as an RLS policy at all; a flat filename leaves no way to say it. No DELETE policy, deliberately: the photo is the evidence behind an approval decision, so neither a driver nor an admin can erase it from the app. Retention is a service-role job, with the schedule at C17. |
| D22 | The one status transition a driver may make | **`resubmit_driver_licence()`, a `security definer` function, `rejected` → `pending` only** | The C3 grants hold `drivers.status` back from `authenticated` entirely, which is right and also means a rejected driver has no way back into the queue. A narrow definer function is exactly the audited hole that privilege needs. It refuses a path outside the caller's own folder — without that check a driver could point their row at someone else's photo and be approved on another person's licence. |
| D23 | What a session is built from | **`go_online()` reads the vehicle and the seat count from `drivers`; the client sends only a route and a destination** | `driver_sessions` had a CHECK tying `seats_total` to `vehicle_type` and nothing tying either to the driver's record — so a boda rider could have opened a bajaj session with three seats and been offered three-seat work. The function also enforces the C6 gate, because a gate in the UI is not a gate. `insert` and most of `update` are revoked from `authenticated` on that table; only `last_pos` stays writable. |
| D24 | Choosing a destination chooses the direction | **No compass, no heading question — just the stage list** | Ubungo→Kimara and Kimara→Ubungo are two route rows over the same tarmac (D-level consequence of the one-row-per-direction decision in §5), so a driver's point sits in both corridors, but any given stage is ahead on exactly one of them. `destinations_ahead()` returns both directions' stages and picking one settles the route. One question instead of two, and the one a driver already knows the answer to. |
| D25 | Rendering locale | **`NjLocale.of(context)`, never `languageProvider`** | They answer different questions. The provider is the first router gate — has a language been confirmed — and `Localizations.localeOf` is what actually chose the strings on screen. A screen reading the provider has two sources of truth that can disagree, and they did: English chrome around a Kiswahili place name. |
| D26 | How the feed stays live | **A broadcast nudge carrying no data, answered by re-running the matching function** — never a subscription to `ride_requests` | Realtime respects RLS, and a driver holds no read policy on that table (§8), so there is nothing to subscribe to — and giving them one to make realtime work would undo the whole model. A trigger broadcasts a route, a vehicle type and a timestamp; the client answers by calling `match_requests_for_session()`, which applies the same scoping it always did. The live part is a doorbell, not a window. |
| D27 | What a broken broadcast may cost | **Latency, and nothing else** | The trigger's whole body is wrapped in an exception handler, so a Realtime outage, a renamed function or a missing schema cannot stop a passenger's request being written. The client polls every 30s alongside the nudge for the same reason. Getting this backwards would mean the notification taking out the thing the app exists to do. |
| D28 | What the client may decide about a request | **The price, the vehicle, and the two stages. Nothing else** | `create_ride_request()` resolves the route from the stage pair and the pickup point from the stage, and refuses a destination that is not further along the same road. The failure it prevents is not an error message — it is a row that saves perfectly and then never appears in any feed, which is the worst kind: everything succeeded and nothing happened. |
| D29 | A passenger at the driver's own stage is a match | **100 m of tolerance behind the driver, not strictly ahead** | `pickup_t > driver_t` excluded the single most likely match there is — somebody waiting at the stage the driver is pulling out of — over a few metres of GPS noise. 100 m is longer than a bus stage and a GPS error, and short enough never to mean turning round in traffic. |
| D30 | `home` is not a screen | **Every gate branch names a real destination; `/` renders a spinner** | Two branches of the driver gate fell through and left an approved driver resting on `/`, which rendered a landing placeholder reading "This screen arrives in the next component" — no way out, and nothing saying why. A redirect that can decline to decide needs somewhere harmless to decline to, and the landing placeholder was not it. |
| D31 | A slow read and a failed read are different answers | **`DriverGate.loading` vs `DriverGate.unreadable`** | They were one value. The rule written for a dead connection — move off `home`, nothing is coming — therefore fired on every cold start, parking an online driver on the direction picker, where the router then correctly left them because a driver is allowed to visit it. One of these resolves itself and the other does not, and the router has to know which. |
| D32 | A passenger has a name | **Asked once after sign-in, gated on a KNOWN empty name** | From C10 a driver is told who they are picking up, and "a passenger" is not something you can call out at a stage. Email stays optional and says so in its own label: Njiani signs in by phone (D10), nothing needs an address, and a required one is a field people put `a@a.com` in. The gate never fires on a profile that is loading or unreadable — being unable to ask for a ride because a nicety could not be read is worse than an unnamed passenger. |
| D18 | State management | **Riverpod without code generation** | `NotifierProvider` directly avoids a `build_runner` step in the build, which keeps `./tool/check.sh` the only thing a contributor has to run. |
| D16 | Screen data during build | **Realistic mock data first**, Supabase wired afterwards | Lets the whole flow be tapped through on a real phone within days, so flow problems surface while they are still cheap. Backend is wired per screen afterwards, with no visual rework. |

### Deferred deliberately

- **Multi-destination sequencing.** Three passengers, three drop points. MVP drops them in
  whatever order the driver taps. Proper route sequencing is v2.
- **No-show handling.** MVP: driver cancels, seat frees, no penalty. Reputation later.
- **Surge / dynamic pricing.** Price bands are hand-seeded (§7), later derived from real trips.
- **Beyond-stage pickup.** MVP pickup points come from the stage list. Free-text addresses need
  geocoding (D9) and arrive at v2.

---

## 3. Repository layout

```
njiani/
├── apps/
│   ├── njiani_rider/            # "Njiani" — passenger app
│   │   ├── lib/
│   │   ├── android/  ios/
│   │   └── pubspec.yaml
│   └── njiani_driver/           # "Njiani Driver"
│       ├── lib/
│       ├── android/  ios/
│       └── pubspec.yaml
├── packages/
│   └── njiani_core/             # shared by both apps
│       └── lib/src/
│           ├── design/          # theme, tokens, widgets (C1)
│           ├── l10n/            # ARB files, en + sw (C2)
│           ├── data/            # Supabase client, repositories, DTOs
│           ├── domain/          # freezed models, enums, value objects
│           └── util/            # geo helpers, formatters (TSh), validators
├── supabase/
│   ├── migrations/              # timestamped SQL, source of truth for schema
│   ├── functions/               # Deno edge functions
│   └── seed.sql                 # Ubungo→Kimara stages + price bands
├── docs/
│   ├── ARCHITECTURE.md          # ← this file
│   ├── BUILD_LOG.md             # per-component record + file changes + test steps
│   └── CREDENTIALS.md           # every credential, blank, with where to get it
├── tool/check.sh                # analyze + test the whole workspace
├── CLAUDE.md                    # working conventions
├── analysis_options.yaml        # one lint config for all three packages
├── pubspec.yaml                 # pub workspace root
└── .env.example                 # every key, blank
```

**Why a monorepo:** two separate store apps (D4) without duplicating the design system,
models, or Supabase layer. A fix in `njiani_core` ships to both apps.

**Workspace mechanism:** native Dart pub workspaces (`resolution: workspace`), Dart 3.6+.
If the installed SDK is older we fall back to `path:` dependencies — same structure, more
boilerplate.

---

## 4. Stack

### Client

| Concern | Package | Note |
| --- | --- | --- |
| Framework | `flutter` 3.27+ | |
| State | `flutter_riverpod` + `riverpod_annotation` | Testable; streams realtime cleanly |
| Routing | `go_router` | Auth + role guards |
| Models | `freezed` + `json_serializable` | Immutable, exhaustive state unions |
| Backend SDK | `supabase_flutter` | Wraps auth, postgrest, realtime, storage |
| Maps | `flutter_map` + `latlong2` → MapLibre at C14 | Behind `MapAdapter` |
| Location | `geolocator`, `permission_handler` | Throttled — battery and data cost matter |
| Push | `firebase_messaging`, `firebase_core` | Only Firebase services used |
| Local store | `shared_preferences` | Session, language. Drift later if offline queue needed |
| i18n | `flutter_localizations`, `intl` + ARB | `en`, `sw` from the first commit |
| Errors | `sentry_flutter` | |
| Fonts | `google_fonts` — Bricolage Grotesque | Matches the pitch design |

### Backend (Supabase)

| Concern | Mechanism |
| --- | --- |
| Database | Postgres 15 + **PostGIS** |
| Auth | Supabase phone OTP, Send-SMS hook → Beem Africa |
| Realtime | Postgres changes on `ride_requests` / `trip_seats` |
| Authorization | Row Level Security on every table, no exceptions |
| Files | Storage, private bucket for driver licence photos, signed URLs only |
| Server logic | Postgres functions (matching, seat claim) + Deno Edge Functions (SMS, admin) |
| Scheduled | `pg_cron` — expire stale requests, close abandoned sessions |

---

## 5. Data model

Each row of `routes` is **one direction of travel**. Ubungo→Kimara and Kimara→Ubungo are two
separate rows with reversed geometry. This is what makes "ahead of me" a simple `>` comparison
along the line (§6) instead of a vector dot product.

```
routes           id, name, direction_label, geom geography(LineString,4326),
                 corridor_m int default 300, active bool

stages           id, route_id → routes, name, name_sw,
                 geom geography(Point,4326), seq int      -- order along the route

price_bands      route_id, from_stage_id, to_stage_id, vehicle_type,
                 low int, high int                        -- TSh, hand-seeded (§7)

profiles         id uuid = auth.users.id, phone, display_name, lang, created_at

drivers          profile_id → profiles (pk), vehicle_type('bajaj'|'boda'),
                 plate, colour, licence_path,
                 status('pending'|'approved'|'rejected'|'suspended'),
                 rating numeric, trips_count int, reviewed_at, reviewed_by

driver_sessions  id, driver_id → drivers, route_id, dest_stage_id,
                 vehicle_type, seats_total, seats_free,
                 last_pos geography(Point,4326), last_pos_at,
                 status('online'|'offline'), went_online_at

ride_requests    id, passenger_id → profiles, route_id,
                 pickup geography(Point,4326), pickup_stage_id nullable,
                 dest_stage_id → stages, vehicle_type,
                 offer_price int, status('open'|'claimed'|'expired'|'cancelled'),
                 created_at, expires_at, claimed_at

trip_seats       id, request_id → ride_requests, session_id → driver_sessions,
                 driver_id, passenger_id, price int,
                 state('claimed'|'aboard'|'dropped'|'cancelled'),
                 claimed_at, aboard_at, dropped_at

ratings          id, trip_seat_id → trip_seats, stars int 1..5, comment, created_at
```

`seats_total` = 3 for bajaj, 1 for boda — enforced by a check constraint against `vehicle_type`.

---

## 6. The two pieces of logic that *are* the product

Everything else in this app is plumbing around these two functions.

### 6.1 Directional corridor matching

A driver heading to Kimara must see a passenger only if that passenger is **(a)** near the
road, **(b)** ahead of where the driver currently is, and **(c)** not past where the driver
is stopping.

```sql
create or replace function public.match_requests_for_session(p_session_id uuid)
returns setof public.ride_requests
language sql stable as $$
  with s as (
    select ds.vehicle_type, ds.seats_free,
           r.geom::geometry              as route_geom,
           r.corridor_m,
           st_linelocatepoint(r.geom::geometry, ds.last_pos::geometry)  as driver_t,
           st_linelocatepoint(r.geom::geometry, dest.geom::geometry)    as dest_t
      from driver_sessions ds
      join routes r     on r.id    = ds.route_id
      join stages dest  on dest.id = ds.dest_stage_id
     where ds.id = p_session_id and ds.status = 'online'
  )
  select rr.*
    from ride_requests rr
    join stages rdest on rdest.id = rr.dest_stage_id
    cross join s
   where rr.status       = 'open'
     and rr.expires_at   > now()
     and rr.vehicle_type = s.vehicle_type
     and s.seats_free    > 0
     -- (a) pickup lies inside the corridor around the road
     and st_dwithin(rr.pickup, s.route_geom::geography, s.corridor_m)
     -- (b) pickup is AHEAD of the driver along the route
     and st_linelocatepoint(s.route_geom, rr.pickup::geometry) > s.driver_t
     -- (c) pickup is not past where the driver stops
     and st_linelocatepoint(s.route_geom, rr.pickup::geometry) <= s.dest_t
     -- (c) passenger's destination is at or before the driver's destination
     and st_linelocatepoint(s.route_geom, rdest.geom::geometry)  <= s.dest_t
   order by st_linelocatepoint(s.route_geom, rr.pickup::geometry) asc;
$$;
```

`ST_LineLocatePoint` returns a 0–1 fraction along the line. Comparing fractions is what makes
"ahead" meaningful. Ordering by it means the nearest passenger ahead is at the top of the feed.

### 6.2 Race-safe seat claiming

Two drivers **will** tap Pickup on the same passenger in the same second. The pitch already
shows the losing state ("Taken by another driver"). This must be one transaction.

```sql
create or replace function public.accept_ride_request(p_request_id uuid, p_session_id uuid)
returns table (ok boolean, reason text, seat_id uuid)
language plpgsql security definer as $$
declare v_seats int; v_price int; v_seat uuid; v_driver uuid; v_passenger uuid;
begin
  -- lock the session row first; establishes a consistent lock order
  select seats_free, driver_id into v_seats, v_driver
    from driver_sessions where id = p_session_id for update;

  if v_seats is null then return query select false, 'no_session', null::uuid; return; end if;
  if v_seats < 1    then return query select false, 'seats_full', null::uuid; return; end if;

  -- the race is decided here: only one UPDATE can move status off 'open'
  update ride_requests
     set status = 'claimed', claimed_at = now()
   where id = p_request_id and status = 'open' and expires_at > now()
   returning offer_price, passenger_id into v_price, v_passenger;

  if not found then return query select false, 'already_taken', null::uuid; return; end if;

  update driver_sessions set seats_free = seats_free - 1 where id = p_session_id;

  insert into trip_seats (request_id, session_id, driver_id, passenger_id, price, state)
       values (p_request_id, p_session_id, v_driver, v_passenger, v_price, 'claimed')
    returning id into v_seat;

  return query select true, 'ok', v_seat;
end $$;
```

The loser gets `already_taken` and the UI shows the red "Taken by another driver" band.

---

## 7. Price bands

Per pitch note n2: the hint under the passenger's price field ("Most drivers on this route take
TSh 1,000 to 1,500") comes from `price_bands`, **hand-seeded per stage pair at launch**, later
derived from accepted trips.

Offers below the band still send — with the warning shown in the mockup. They are not blocked.

> **Recommendation:** log every request that expires **unmatched**, with its offer. Rejected
> offers reveal the true price floor faster than accepted ones do.

---

## 8. Security model

Every table has RLS enabled. Summary of intent (exact policies land in C3):

- `profiles` — a user reads and writes only their own row, and only three columns of it:
  `display_name`, `email` and `lang`. `phone` is held back by GRANT, for the same reason
  `drivers.status` is: it is the account's identity, Supabase Auth owns it, and moving it in the
  app would point a verified session at someone else's number. Email is optional, loosely
  checked, and normalised to lower case — case and whitespace are not identity.
- `drivers` — a driver reads/writes their own row; `status` is **not** writable by the driver
  (only by an admin role). This is the verification gate.
- `driver_sessions` — a driver writes only their own session, and barely any of it.
  `insert` and `update` are revoked from `authenticated` except for `last_pos` and
  `last_pos_at`; sessions are opened by `go_online()` and closed by `go_offline()`, both
  `security definer`. `go_online` enforces the C6 approval gate, reads the vehicle type and
  seat count from `drivers` rather than from the client (D23), refuses a destination that is
  not on the declared route, and opens with the seats that are genuinely free — a driver
  changing direction mid-trip keeps the passengers already with them. Passengers never read
  raw sessions.
- `ride_requests` — a passenger writes only their own. Drivers **never** hold a blanket read
  policy; they read matches **only** through `match_requests_for_session()`, which is scoped to
  their own online session. A driver cannot enumerate the request table.
- `trip_seats` — readable by the passenger on the seat and the driver holding it, nobody else.
- The feed's realtime signal — a private Broadcast topic per route and vehicle type. The
  `realtime.messages` policy lets a driver subscribe only while they are online on that route,
  and the payload carries a route id, a vehicle type and a timestamp: no request, no price, no
  destination, no passenger (D26). A driver also never sees their own request in their own
  feed — claiming it would write a seat whose driver and passenger are the same person.
- `licence_path` files — private `licences` bucket, signed URLs, read by the owner and by
  admins and nobody else. The path is `<uid>/licence.<ext>`, so the owner is the first folder
  segment and the policy can match on it. **No DELETE policy at all** (D21). Storage enforces a
  5 MB cap and an image-only MIME allow-list before a byte is written, so those are limits
  rather than client-side courtesies.
- `drivers.status` — moved only by `review_driver()`, which requires a reason for every rejection
  and stamps who decided it. A driver's single permitted transition is
  `resubmit_driver_licence()` (D22), `rejected` → `pending`, which leaves the vehicle, plate and
  colour untouched: re-submission does not reset the other checks.
- Passenger phone numbers are revealed to a driver **only after** a seat is claimed, and only for
  that seat. Same in reverse.

---

## 9. Environments

| | Local | Dev | Production |
| --- | --- | --- | --- |
| Database | `supabase start` (Docker) | Hosted free project | Hosted paid project |
| SMS | Console-logged OTP, no SMS sent | Real gateway, test sender | Real gateway, `NJIANI` sender ID |
| Config | `.env.local` | `.env.dev` | CI secrets, never in repo |

Migrations are the only source of schema truth. Nothing is changed by clicking in Studio.

---

## 10. Component roadmap

Build order. **One component at a time.** Each is documented in `BUILD_LOG.md` with exact file
changes and test steps, and each waits for your local sign-off before the next begins.

| # | Component | Signed off when you can |
| --- | --- | --- |
| C0 | Monorepo scaffold, both app shells, docs, `.env.example` | ✅ `flutter run` boots both apps on iOS and Android |
| C1 | Design system — **rebuilt from the design project** (D14), light + dark, shared components | 🔄 Reopened. Gallery renders the real design language |
| C2 | `pLang` + i18n (EN/SW), `go_router` guard, Riverpod, persistence | ✅ Flip language; restart and it is remembered |
| C3 | Supabase schema, PostGIS, RLS, Ubungo→Kimara seed | ✅ Migrations run; 168 SQL assertions pass |
| C4 | `pPhone` + `pOtp` — Supabase phone OTP, Beem delivery | ✅ Log in on your own phone |
| C5 | Profile + session persistence | ✅ Kill the app, reopen, still logged in |
| C6 | Driver signup, licence upload, pending screen, approval | ✅ Submit → approve in Studio → screen changes, with nothing tapped |
| C7 | Driver direction picker, go online, route board, seat bar | ✅ Pick Kimara, go online |
| C8 | Passenger request — destination, vehicle, price, hint band | 🧪 Send a request, and watch it land in the driver's feed |
| C9 | **Live matching feed** — the PostGIS query + realtime | 🧪 Request appears in the feed without a tap. Phone A is the rider app from C8 |
| C10 | **Atomic seat claim** | Two devices race one request; one wins, one sees "Taken" |
| C11 | Trip lifecycle both sides, cancels, earnings tally | A full ride, end to end |
| C12 | Ratings + trip history | Rate a trip, see it stored |
| C13 | Push notifications (FCM) | Request arrives with the app backgrounded |
| C14 | MapLibre + `.pmtiles` + live position + OSRM ETA | Watch the driver marker move |
| C15 | Safety — share trip, help, 112 | Share link opens |
| C16 | Admin web (Flutter Web) — driver queue, price band editor | Approve a driver from a browser |
| C17 | Hardening — offline, errors, analytics, rate limits | Airplane mode behaves sanely |
| C18 | Release prep — icons, signing, store checklists | Build a signed release for both stores |

**C9 and C10 are the product.** C0–C8 is plumbing to reach them; C11–C18 is polish around them.
If you want to reach them sooner, say so and we can stub auth and come back to it.

### Revised shape from C2 onward (D15, D16)

The redesign is organised as screens, so the build unit changes to match. C2 onward becomes one
screen per sign-off, each built against realistic mock data, in the order the design presents
them. The backend components (C3, C9, C10) keep their place in the plan — screens are wired to
Supabase after the flow has been judged on a real device. The numbered list above stays the
commitment; what changes is that a "component" is now usually a screen.

### The screen list

Taken from the design project's own navigation, which keys every screen to a component.
**23 screens plus the gallery.** Order within a component follows the flow, not the list.

**Rider — "Njiani"**

| Screen | Component | What it is |
| --- | --- | --- |
| `pLang` | **C2** | Language choice. Kiswahili pre-selected, shown once before auth |
| `pPhone` | **C4** | Phone number, `+255` fixed in the field |
| `pOtp` | **C4** | Four-box code, auto-advancing |
| `pHome` | **C8** | Request a ride: destination, vehicle, price per seat |
| `pSearch` | **C9** | Searching, with the real count of drivers who can see the offer |
| `pNoDriver` | **C9** | Nobody took it — expiry, with the band and a one-tap fix |
| `pMatched` | **C10** | Driver on the way. Phone numbers revealed only now |
| `pTrip` | **C11** | On the trip. Route board, agreed price, safety one tap away |
| `pRate` | **C12** | Arrived and rate. Skippable |
| `pHistory` | **C12** | Trip history — the only record of an off-app settlement |
| `pSafety` | **C15** | Share, call, report, and 112 |
| `pOffline` | **C17** | Connection lost, honest degraded state |
| `pPlaces` | *V2* | Saved places — designed so C8 leaves room for it |
| `pCounter` | *V2* | Counter-offer — designed to show why it is not MVP |

**Driver — "Njiani Driver"**

| Screen | Component | What it is |
| --- | --- | --- |
| `dSignup` | **C6** | Sign up. The verification gate |
| `dPending` | **C6** | Under review |
| `dRejected` | **C6** | Rejected, naming the single thing to fix |
| `dDirection` | **C7** | Pick a direction — the screen that makes Njiani not ride-hailing |
| `dStage` | **§13.1** | Stage mode: where demand is, for a parked driver |
| `dFeed` | **C9 / C10** | Live requests and the atomic claim. **The product** |
| `dOnboard` | **C11** | On board, with v2 drop sequencing shown |
| `dEarnings` | **C11** | Earnings and the weekly fee, made legible before it starts |
| `dHistory` | **C12** | Seven days, grouped by day |

**Design system**

| Screen | Component | What it is |
| --- | --- | --- |
| `gallery` | **C1** | The component state matrix, both themes |

Two screens in the design are marked **V2** and are deliberately not in the MVP. They are drawn
so the MVP layout leaves room for them, and so the cost of `pCounter` in particular is visible:
a counter-offer turns one atomic claim into a negotiation with its own state machine, timeouts
and race conditions.

The design also adopts §13.1 (stage mode) from the suggestions in §13 of this document.

---

## 11. Payments — explicit scope

**In scope:** the app records the agreed price and shows it to both parties. Settlement happens
person-to-person, in cash or by mobile money, exactly as it does today.

**Out of scope:** in-app collection, wallets, escrow, split payments, automatic driver payouts.

**Why:** collecting money in Tanzania means an aggregator (Selcom, Azampay, ClickPesa, DPO),
merchant onboarding, reconciliation, refunds and the compliance that comes with holding funds.
That is roughly four more components and a licensing conversation, for zero added value at a
15-driver pilot where cash already works.

**When it changes:** when the weekly driver subscription fee replaces free access. That needs
collection from *drivers* — a much simpler, lower-volume flow than per-trip passenger payments.

---

## 12. Regulatory and safety notes

Not blockers for building, but they are real and they have lead times.

- **LATRA.** Ride-hailing platforms in Tanzania require LATRA registration, and fare regulation
  has historically applied to the sector. *"Passenger names their own price"* is the core
  mechanic and may interact with fare rules — worth confirming before launch, not after.
  Slide 6 of the pitch already flags this.
- **Boda boda passenger carriage.** Legal status varies by ward and has been restricted in parts
  of Dar. Confirm for the specific corridor before onboarding boda drivers.
- **SMS sender ID.** Registering `NJIANI` with a Tanzanian gateway takes several business days.
  **Start this application at C0**, or C4 will block on it.
- **Driver verification is the safety floor.** Licence photo review is manual and must stay
  manual at this size. `drivers.status` is admin-writable only (§8).
- **Data protection.** Tanzania's Personal Data Protection Act (2022) applies. Phone numbers,
  location traces and licence images are personal data. Location history retention should be
  bounded — proposal: raw position traces purged after 30 days, trip records retained.

---

## 13. Suggestions on the table

Not committed, raised for your call:

1. **Driver "stage mode".** When a driver is parked with no heading chosen, show where demand is
   right now — *"4 people waiting toward Kimara"*. Cheap on the same query, and it attacks
   problem #3 on slide 2 more directly than the current flow does.
2. **An ops screen for you at C16.** Live open requests, online drivers, median time-to-match.
   You will want it in your hand at the stages on day one, and it is exactly the metrics list
   from slide 6.
3. **Log unmatched expiries** (§7) — your fastest route to real price bands.

---

## 14. Credentials

No credential is ever committed. Every one is listed blank in
[`CREDENTIALS.md`](./CREDENTIALS.md) with where to obtain it and where to put it, and repeated
in the `BUILD_LOG.md` entry of the component that first needs it.
