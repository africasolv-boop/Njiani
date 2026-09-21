# Njiani — Build Log

> One entry per component. Each entry records **what was built**, **every file changed**, **how
> you test it locally**, and **which credentials it needs**.
>
> **Process:** I build one component → I write its entry here → you pull, test on your Mac
> (iOS + Android) → you sign off → I start the next. Nothing proceeds without sign-off.

**Status key:** 🔜 not started · 🔨 in progress · 🧪 awaiting your test · ✅ signed off

---

## Progress

| # | Component | Status | Signed off |
| --- | --- | --- | --- |
| — | Planning & architecture | ✅ | 2026-09-21 |
| C0 | Monorepo scaffold + both app shells | 🧪 awaiting your test | |
| C1 | Design system | 🔜 | |
| C2 | i18n + routing + app shells | 🔜 | |
| C3 | Supabase schema + PostGIS + RLS + seed | 🔜 | |
| C4 | Phone + OTP auth | 🔜 | |
| C5 | Profile + session persistence | 🔜 | |
| C6 | Driver onboarding + verification | 🔜 | |
| C7 | Driver direction + go online | 🔜 | |
| C8 | Passenger request | 🔜 | |
| C9 | Live matching feed | 🔜 | |
| C10 | Atomic seat claim | 🔜 | |
| C11 | Trip lifecycle | 🔜 | |
| C12 | Ratings + history | 🔜 | |
| C13 | Push notifications | 🔜 | |
| C14 | MapLibre + live position + ETA | 🔜 | |
| C15 | Safety features | 🔜 | |
| C16 | Admin web | 🔜 | |
| C17 | Hardening | 🔜 | |
| C18 | Release prep | 🔜 | |

---

## Entry template

Each component below follows this shape:

> ### Cn — Name  ·  `status`
> **Goal** — one sentence: what this component makes possible that was not possible before.
> **Credentials needed** — or "none".
> **Files added / changed** — complete list, grouped, with a note on each.
> **How to test** — exact commands, then numbered steps with expected results, for iOS *and*
> Android.
> **Known gaps** — what is deliberately not done yet and which component picks it up.
> **Sign-off** — you write "approved" or what is wrong.

---

## Planning & Architecture · ✅ signed off

**Goal** — agree the stack, the data model, the matching logic and the build order before any
application code is written.

**Credentials needed** — none.

**Files added**

| File | What it is |
| --- | --- |
| `docs/ARCHITECTURE.md` | **The master document.** Product definition, decision log with reasoning, repo layout, stack, data model, the two core SQL functions, security model, environments, the C0–C18 roadmap, payment scope, regulatory notes |
| `docs/BUILD_LOG.md` | This file |
| `docs/CREDENTIALS.md` | Every credential, blank, with where to get it, where it goes, and when it is first needed |

**Decisions recorded** (full reasoning in `ARCHITECTURE.md` §2)

- **D1** Supabase (Postgres + PostGIS + Realtime + RLS), **D2** Firebase for push only
- **D3** Flutter 3.27+, **D4** two apps from one monorepo with a shared `njiani_core` package
- **D5** macOS + iPhone + Android for local testing
- **D6/D7** `flutter_map` behind a `MapAdapter` now → MapLibre + self-hosted `.pmtiles` at C14
- **D8** haversine ETA now → self-hosted OSRM at C14
- **D9** no geocoding in MVP (matching runs on named stages)
- **D10** Supabase phone OTP via a Tanzanian SMS gateway with a `NJIANI` sender ID
- **D11** cash / direct mobile money — the app records the amount, it does not move money
- **D12** Supabase Studio for admin until C16, **D13** Sentry for errors

**How to review**

1. Read `docs/ARCHITECTURE.md` §2 (decision log) first — that is where every choice is justified.
2. §6 is the heart of it: the corridor-matching query and the race-safe seat claim. If those two
   are right, the product works.
3. §11 (payments scope) and §12 (LATRA, boda legality, data protection) are the two places I
   have made assumptions you may want to overrule.
4. §13 lists three suggestions awaiting your yes or no.

**Action items for you, independent of code** — these have lead times:

- [ ] Apply for the `NJIANI` alphanumeric SMS sender ID (several business days — blocks C4)
- [ ] Confirm LATRA's position on a passenger-set-price model (§12)
- [ ] Confirm boda boda passenger carriage is permitted on the Ubungo–Kimara corridor
- [ ] Decide on the three suggestions in §13

**Known gaps** — no code, no Supabase project, no Flutter workspace. C0 creates all three.

**Sign-off** — approved 2026-09-21. Beem sender ID application in progress.

---

## C0 — Monorepo scaffold + both app shells · 🧪 awaiting your test

**Goal** — both apps build, launch and render shared code from `njiani_core` on your iPhone and
your Android device, with a lint and test harness that guards everything built after this.

**Credentials needed** — **none.** C0 runs entirely offline. `.env.local` can stay empty.

### What it does

Both apps launch to a boot screen that proves three things on the device itself:

1. the app builds and runs on iOS and Android,
2. it is rendering code from `njiani_core` — the entire screen lives in the shared package, so
   if you can see it, the monorepo wiring genuinely works rather than merely existing,
3. **which credentials are still unset and which component needs each one**, read live from the
   build configuration. An unset key is visible on the phone instead of surfacing later as a
   confusing runtime error.

The two apps are verifiably distinct: different bundle ids, different names on the home screen,
different taglines — and a test that fails if the two `main()` files are ever left identical.

### Files added

**Workspace root**

| File | What it is |
| --- | --- |
| `pubspec.yaml` | Dart pub workspace root. One lockfile for all three packages |
| `analysis_options.yaml` | One lint config governing both apps and the shared package. `unawaited_futures`, `cancel_subscriptions` and `close_sinks` are on — they matter once realtime streams and location listeners arrive |
| `.gitignore` | Credential patterns first and loudest, then Flutter/Android/iOS/Supabase |
| `.env.example` | Every key, blank, grouped by the component that needs it |
| `CLAUDE.md` | Working conventions: shared code rules, credential rules, migration rules |
| `README.md` | Rewritten — layout, docs index, run and check commands |
| `tool/check.sh` | Runs `flutter analyze` plus every package's tests. `flutter test` cannot run from a workspace root, so this walks the members |

**`packages/njiani_core/`** — shared by both apps

| File | What it is |
| --- | --- |
| `pubspec.yaml` | `resolution: workspace` |
| `lib/njiani_core.dart` | Barrel export — the only import either app needs |
| `lib/src/config/app_config.dart` | Build-time config via `--dart-define`. Every key defaults to empty, so nothing can reach production by accident. `entries` drives the on-device credential checklist; secrets render as a length fingerprint, never a value |
| `lib/src/config/app_identity.dart` | `NjianiApp` enum — which of the two apps this binary is, with its label, bundle id and both taglines |
| `lib/src/boot/njiani_mark.dart` | The Njiani logo, drawn with `CustomPainter` from the pitch deck's SVG path. No asset, no SVG dependency, scales cleanly |
| `lib/src/boot/boot_screen.dart` | The shared boot screen |
| `lib/src/boot/boot_app.dart` | Thin `MaterialApp`. Placeholder theme — C1 replaces it |
| `test/config_test.dart` | 10 tests: config invariants, secret redaction, bundle ids are App Store safe (no underscores), both languages present |
| `test/boot_screen_test.dart` | 7 tests: both apps render their own identity, in light and dark, on a small low-end handset screen, without overflow |

**`apps/njiani_rider/`** — "Njiani", `tz.njiani.rider`

| File | What it is |
| --- | --- |
| `pubspec.yaml` | `resolution: workspace`, depends on `njiani_core` |
| `lib/main.dart` | One line. Everything shared lives in `njiani_core` and this file should stay thin |
| `test/boot_test.dart` | 3 tests including one that fails if the two apps' `main()` are ever left identical |
| `android/`, `ios/` | Platform folders. Identifiers corrected to `tz.njiani.rider`, Kotlin package path moved to match, display name set to **Njiani** |

**`apps/njiani_driver/`** — "Njiani Driver", `tz.njiani.driver` — same shape, display name **Njiani Driver**.

### Identifier fix worth knowing about

`flutter create` produced `tz.njiani.njiani_rider` and `tz.njiani.njianiRider`. Both were
corrected to `tz.njiani.rider` / `tz.njiani.driver`, including moving the Kotlin `MainActivity`
to a matching package path. This matters because **Apple rejects underscores in bundle
identifiers**, and changing an identifier after a store release is not possible — it would be a
new app listing. There is a test asserting the identifiers stay App Store safe.

---

### How to test

```sh
git pull
flutter pub get          # at the repo root — resolves all three packages at once
cp .env.example .env.local
./tool/check.sh          # expect: no analyzer issues, 23 tests passing
```

Then run each app. **Both apps can be installed side by side** — different bundle ids.

```sh
cd apps/njiani_rider  && flutter run --dart-define-from-file=../../.env.local
cd apps/njiani_driver && flutter run --dart-define-from-file=../../.env.local
```

**On each of iOS and Android, check:**

| # | Step | Expected |
| --- | --- | --- |
| 1 | Launch the rider app | Yellow Njiani mark, title **Njiani**, tagline in English then Kiswahili |
| 2 | Launch the driver app | Title **Njiani Driver**, its own Kiswahili tagline |
| 3 | Both installed at once | Two separate icons, **Njiani** and **Njiani Driver** |
| 4 | Read the "Wiring" block | `Rendered by: package njiani_core`, and the right bundle id per app |
| 5 | Scroll to "Configuration" | Five credentials, all showing **not set**, each tagged with the component that needs it (C3/C14/C17) |
| 6 | Switch the device to dark mode | Both apps follow it, still readable |
| 7 | Rotate to landscape | Content scrolls, nothing overflows |

**Optional, to see the credential checklist work:** put any value in `SUPABASE_URL` in
`.env.local`, re-run, and that row flips to a tick. Put something in `SUPABASE_ANON_KEY` and it
shows `•••• set (N chars)` — never the value itself.

### What I verified here, and what I could not

**Verified in this session** — `flutter analyze` clean across the workspace, all **23 tests
passing** (17 in `njiani_core`, 3 per app), on Flutter 3.47.5 / Dart 3.13.4.

**Not verified** — there is no Android SDK or Xcode in my environment, so I have **not** compiled
an APK or an iOS build, and have not seen the screen on a real device. Step 1 of your test is the
first time this runs on real hardware. If it fails at the build stage rather than the display
stage, that is where to look first.

### Known gaps — deliberate

| Gap | Picked up by |
| --- | --- |
| Placeholder theme, not the pitch's colours or Bricolage Grotesque | **C1** |
| No Kiswahili switching — the boot screen just prints both | **C2** |
| No routing, no state management | **C2** |
| No backend, no `supabase/` directory yet | **C3** |
| App icons are still Flutter's default | **C18** |
| `SMS_*` keys are in `.env.example` but unused — they are server-side only | **C4** |

### Sign-off

_Awaiting your test._
