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
| D10 | SMS / OTP | Supabase phone auth + **Send-SMS hook → Tanzanian gateway** (Beem Africa or Africa's Talking), Twilio as fallback | ~TSh 20–30/SMS vs international rates, better local delivery, and a branded `NJIANI` sender ID — which matters when asking a driver at a stage to trust a code. |
| D11 | Payments | **Cash / direct mobile money. App records the amount only.** | No wallet, no escrow, no aggregator licensing. Revisit when the weekly driver fee launches. See §11. |
| D12 | Admin | Supabase Studio + SQL views → Flutter Web admin at C16 | Do not build a dashboard before there is data to put in it. |
| D13 | Error tracking | **Sentry** | Better Flutter stack traces than Crashlytics; generous free tier. |
| D14 | Source of visual truth | **The Claude Design project (`Njiani Apps.dc.html`)**, not the pitch deck | The pitch deck was a prototype, not a design. C1's first pass was built from its CSS and did not land. The design project supersedes it for every visual decision from here. |
| D15 | Build unit after C1 | **One screen at a time**, not one component at a time | The redesign is organised as screens. Shared components are extracted into `njiani_core` as part of the revised C1, then screens are built on top, one per sign-off. |
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

- `profiles` — a user reads and writes only their own row.
- `drivers` — a driver reads/writes their own row; `status` is **not** writable by the driver
  (only by an admin role). This is the verification gate.
- `driver_sessions` — a driver writes only their own session. Passengers never read raw sessions.
- `ride_requests` — a passenger writes only their own. Drivers **never** hold a blanket read
  policy; they read matches **only** through `match_requests_for_session()`, which is scoped to
  their own online session. A driver cannot enumerate the request table.
- `trip_seats` — readable by the passenger on the seat and the driver holding it, nobody else.
- `licence_path` files — private Storage bucket, signed URLs, admin-only read.
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
| C2 | i18n (EN/SW), `go_router` shells, splash | Flip language; every string translates |
| C3 | Supabase schema, PostGIS, RLS, Ubungo→Kimara seed | Migrations run; stages visible in Studio |
| C4 | Phone + OTP auth (dev mode prints the code) | Log in on your own phone |
| C5 | Profile + session persistence | Kill the app, reopen, still logged in |
| C6 | Driver signup, licence upload, pending screen, approval | Submit → approve in Studio → screen changes |
| C7 | Driver direction picker, go online, route board, seat bar | Pick Kimara, go online |
| C8 | Passenger request — destination, vehicle, price, hint band | Send a request |
| C9 | **Live matching feed** — the PostGIS query + realtime | Request on phone A appears on phone B |
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

The exact screen list is set once the design project has been read.

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
