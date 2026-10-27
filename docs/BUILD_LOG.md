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
| C0 | Monorepo scaffold + both app shells | ✅ | 2026-09-21 |
| C1 | Design system (rev. 2, from the design project) | ✅ | 2026-09-21 |
| C2 | `pLang` — language choice, i18n, routing | ✅ | 2026-09-22 |
| C3 | Supabase schema + PostGIS + RLS + seed | ✅ | 2026-10-21 |
| C4 | `pPhone` + `pOtp` — phone and SMS code | 🧪 awaiting your test | |
| C5 | Profile + `profiles.lang` + session persistence | 🧪 awaiting your test | |
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

## C0 — Monorepo scaffold + both app shells · ✅ signed off

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

Approved 2026-09-21.

---

## C1 — Design system · 🔄 reopened

**Goal** — the pitch deck's visual language becomes a real Flutter theme plus 18 reusable
components, judged side by side against the mockups in both light and dark.

**Credentials needed** — **none.**

### What it does

Both apps now open a **component gallery**: every component on one scrolling screen, with a
theme toggle in the app bar so you can flip light and dark without leaving your place in the
list. Everything is interactive — tap the seats to fill them, tap the chips, type in the code
boxes, toggle the licence upload.

The C0 boot screen is still there, behind the ⓘ button, so the credential checklist stays
reachable.

### Design decisions worth your opinion

| Decision | Reasoning |
| --- | --- |
| **Yellow means commitment** | The bajaj yellow button is reserved for the decisive tap — *Send request*, *Start heading to Kimara*. Teal carries routine actions. So the irreversible tap never looks like the routine one. |
| **Bajaj yellow does not change in dark mode** | It imitates physical objects — the vehicles, and the painted daladala route boards. A route board does not have a dark mode. Same for the number plate and the green "live" dot. There is a test asserting this. |
| **The font is bundled, not downloaded** | `google_fonts` fetches at runtime. Drivers are on metered data, and text that reflows after a network fetch reads as a bug. 420 KB for five weights, shipped in the binary. |
| **2pt outlines, not Material hairlines** | These screens are used outdoors in Dar sunlight, where Material's default 1px underline disappears. |
| **No profile photos** | Drivers are verified by licence and identified by plate, so initials suffice — and there is no photo to collect, store or protect. |
| **A price hint warns, it never blocks** | An offer below the usual band still sends. The passenger sets the price; the app only says what usually works. |

### Files added

**Design tokens** — `packages/njiani_core/lib/src/design/`

| File | What it is |
| --- | --- |
| `nj_colors.dart` | All 19 colour tokens from the pitch CSS, as a typed `ThemeExtension`. Material's `ColorScheme` has no slot for "bajaj yellow" or "map road", so they live here rather than being forced into approximate Material roles |
| `nj_tokens.dart` | Spacing scale, radii, border widths, durations, shadows |
| `nj_typography.dart` | The type scale, converted from the deck's rem values |
| `nj_theme.dart` | `NjTheme.light` / `NjTheme.dark`, plus the `context.nj` accessor |

**Components** — `packages/njiani_core/lib/src/widgets/` — 18 files

`NjButton` (4 variants, loading state) · `NjTextField` (prefix, error) · `NjOtpField` ·
`NjSegmented` · `NjPriceChips` / `NjChoiceChip` · **`NjRouteBoard`** · **`NjSeatIndicator`** ·
**`NjPlateBadge`** · `NjCard` (filled/outlined) · `NjAvatar` · `NjHint` · `NjEmptyState` ·
`NjLiveDot` · `NjSheet` · `NjToast` · `NjStars` · `NjUploadBox` · `NjWhereRow`

**Other**

| File | What it is |
| --- | --- |
| `lib/src/util/money.dart` | `tsh(1500)` → `TSh 1,500`. Hand-rolled rather than pulling in `intl` for one grouping rule |
| `lib/src/gallery/gallery_screen.dart` | The gallery |
| `lib/src/gallery/gallery_app.dart` | Hosts it with its own theme switch |
| `assets/fonts/` | Bricolage Grotesque, 5 weights + `OFL.txt` |
| `lib/njiani_core.dart` | Barrel, now exporting the design system |
| `apps/*/lib/main.dart` | Both now run the gallery |

**Tests added** — 61 new, 84 total

| File | Covers |
| --- | --- |
| `test/theme_test.dart` | Token invariants, `lerp`/`copyWith`, theme registration, `context.nj` fallback — and **16 WCAG contrast assertions** |
| `test/widgets_test.dart` | Behaviour of every interactive component, plus a gallery scroll that fails on any layout overflow |
| `test/money_test.dart` | Shilling formatting |

### The contrast tests

Sixteen assertions check every foreground/background pair real text actually lands on, in both
themes, against WCAG 2.1 — 4.5:1 for body text, 3:1 for large bold button labels. All pass.
This is the part eyeballing a palette does not catch: if a token is ever nudged and quietly
becomes unreadable, the build fails instead of the driver squinting.

### Two real bugs the tests caught

1. **Plate badge overflow.** A `NjPlateBadge` beside a text label overflowed by 56px on a narrow
   screen. A plate is fixed-width content and deliberately does not shrink — a half-rendered
   plate is worse than useless for identifying a vehicle — so the fix is that *siblings* must be
   flexible. Fixed at both call sites and documented on the component itself.
2. **An identity test that could not fail.** The C0 test asserting each app shows its own name
   used substring matching — but "Njiani Driver" contains "Njiani", so it could never
   distinguish them. Now asserts on the widget properties instead.

---

### How to test

```sh
git pull
flutter pub get
./tool/check.sh          # expect: no analyzer issues, 84 tests passing

cd apps/njiani_rider  && flutter run --dart-define-from-file=../../.env.local
cd apps/njiani_driver && flutter run --dart-define-from-file=../../.env.local
```

**On each of iOS and Android:**

| # | Step | Expected |
| --- | --- | --- |
| 1 | Launch either app | The component gallery, in Bricolage Grotesque |
| 2 | Tap the moon/sun in the app bar | The whole palette flips. Check that **yellow stays yellow** — route board, plate, buttons |
| 3 | Scroll to **Route board** | Compare against slide 4 of the pitch. This is the signature component |
| 4 | Tap the seat blocks | They fill teal, one per tap, then wrap back to empty |
| 5 | Tap the price chips | Selected chip gets a teal border and tint |
| 6 | Tap **Send request** | A dark toast appears bottom, then fades |
| 7 | Tap **Finding a driver** | Spinner for 2 seconds; the button ignores further taps |
| 8 | Type in the 4 code boxes | Focus advances; backspace on an empty box steps back |
| 9 | Tap the licence upload box | Dashed grey → solid teal with a tick |
| 10 | Tap the stars | Rating changes |
| 11 | Tap ⓘ in the app bar | The C0 boot screen with the credential checklist |
| 12 | Rotate to landscape, scroll the whole list | No yellow-and-black overflow stripes anywhere |

**What I most want your opinion on:** step 3 (does the route board read like a daladala board?)
and step 2 (does the dark palette hold up, or does anything disappear?).

### What I verified here, and what I could not

**Verified** — `flutter analyze` clean, **84 tests passing**, including 16 contrast assertions
and a full gallery scroll that fails on any overflow.

**Not verified** — still no Android SDK or Xcode here, so no compiled build and no real device.
Specifically unverified: **how Bricolage Grotesque actually renders.** Flutter's test
environment substitutes a fixed-width test font, so every text measurement in my tests is
approximate. If something is clipped or mis-spaced on your device, the font metrics are the
first place to look.

### Known gaps — deliberate

| Gap | Picked up by |
| --- | --- |
| Gallery strings are English-only | **C2** — localisation |
| No map component yet | **C14** |
| No routing; the gallery is the whole app | **C2** |
| `NjToast` uses a raw `Overlay`; no queueing if two fire at once | revisit if it bites |
| Gallery ships in the release binary | **C18** removes it |

### Sign-off

**Not accepted — reopened 2026-09-21.** The visual language did not land. Root cause: this pass
was built from the pitch deck's CSS, which was a clickable prototype rather than a design. A full
redesign now exists as a Claude Design project (`Njiani Apps.dc.html`), and that supersedes the
pitch deck as the source of visual truth (decision D14).

**What is being kept** — the structural work is sound and independent of the visuals: the
`ThemeExtension` mechanism, `context.nj`, the token architecture, the bundled-font decision, the
16 WCAG contrast assertions, and the gallery harness. All of it re-points at new values.

**What is being replaced** — every colour, size, radius and component appearance, redrawn from
the design project.

**Follow-on decisions taken with this** — D15: the build unit after C1 becomes one screen at a
time, matching how the redesign is organised. D16: screens are built against realistic mock data
first, so the whole flow can be tapped through on a real phone within days.

### C1 rev. 2 — delivered, see below

---

## Stale template files — fixed 2026-09-21

**Symptom** — `flutter analyze` reported two errors that do not exist in the repository:

```
error - The name 'MyApp' isn't a class - apps\njiani_driver\test\widget_test.dart:16:35
error - The name 'MyApp' isn't a class - apps\njiani_rider\test\widget_test.dart:16:35
```

**Cause** — `widget_test.dart` is generated by `flutter create` and was removed during C0 before
the first commit, so it was never tracked. `git pull` cannot delete an untracked file, so it
survives in any working tree that has run `flutter create` and breaks the build with errors that
are invisible to everyone else.

**Fix** — `tool/check.sh` now guards against this before it runs anything else. It checks for
every file `flutter create` generates that the repo deliberately does not carry, including
per-package `analysis_options.yaml` (which would silently override the workspace lint config) and
stray `pubspec.lock` files (which break workspace resolution).

```sh
./tool/check.sh          # reports stale files and exits 1, with the exact rm command
./tool/check.sh --fix    # deletes them, then runs the checks
```

Verified: the guard exits 1 with a stale file present, and `--fix` clears it and passes.

---

## C1 rev. 2 — Design system from the design project · ✅ signed off

**Goal** — bring the design system into line with `Njiani Apps.dc.html`, and rebuild the gallery
as the state matrix that file's `gallery` spec asks for.

**Credentials needed** — **none.**

### What reading the design actually found

The design project's token list is **identical to what `njiani_core` already shipped** — every
hex, in both themes — and it names the same 18 widgets. Its own gallery spec says:

> *"njiani_core already ships 18 widgets, the token set and a gallery screen. This is the state
> matrix that gallery should render, so a missing state gets caught here instead of in a flow."*

So the design was written **on top of** C1 rev. 1, not to replace it. It also cites this
repository's `ARCHITECTURE.md` (§2, §11, §12, D9) and adopts §13.1, stage mode, from the
suggestions list.

That turned C1 rev. 2 from "start over" into four concrete jobs: prove the tokens match, add the
components the 23 screens need, add the missing states, and rebuild the gallery as a matrix.

### 1. Conformance — the tokens are now asserted against the design

`test/design_conformance_test.dart` transcribes the design's own swatch list and inline styles
and asserts the code against them: **13 tests** covering both palettes, the plate colours, the
type scale, every radius, the button heights, and font resolution. A token drifting away from
the design now fails the build instead of being found on a device weeks later.

### 2. Components added — 7 new, for the screens ahead

| Component | Needed by |
| --- | --- |
| `NjActionTile` | `pSafety`, `pPlaces` — 64pt row, icon chip, title and a line saying what happens |
| `NjBadge` | Scope markers (`V2`, `§13.1`) and status pills (`TSh 0`) |
| `NjBanner` | `pOffline`, `dRejected` — inline alert |
| `NjStatCard` | `dEarnings` — the ink hero card carrying the figure a driver opens the app for |
| `NjMeter` / `NjSegmentBar` | Countdown, demand bars, seats-filled blocks |
| `NjStatusRow` | `dRejected` — the checklist showing what passed |
| `NjSkeleton` / `NjSkeletonCard` | `pHistory`, `dHistory` — the spec asks for skeletons, not spinners |

**25 components total.**

### 3. States added — the matrix the spec enumerates

| Component | Added |
| --- | --- |
| `NjButton` | `NjButtonSize.compact` (48pt, radius 12) for in-feed actions; `NjButtonVariant.blocked` for "Seats full" |
| `NjUploadBox` | `uploading` (with progress) and `failed`, replacing a bool with `NjUploadState` |
| `NjOtpField` | A wrong code now clears the boxes and refocuses the first, per the spec |
| `NjSegmented` | 3-up verified alongside 2-up |
| Theme | Focus ring is bajaj yellow, so focus never reads as an error or a selection |

**`blocked` is deliberately not `disabled`.** A dimmed button reads as "not yet"; "Seats full" at
full opacity reads as "not possible, and here is why". The design calls for both and they mean
different things to a driver. There is a test asserting they do not look alike.

### 4. The gallery is now a dual-theme state matrix

Every component renders **in both themes in the same view** — light above dark on a phone, side
by side above 620pt. That is the spec's requirement, and it is the only arrangement that catches
a token which works in one theme and disappears in the other.

### A correction to what I reported earlier

I said the bare `ThemeData.fontFamily` was *likely why the build looked wrong*. **That was wrong,
and I said it before verifying.** Probing the real values showed `textTheme` was already
resolving correctly to `packages/njiani_core/BricolageGrotesque`, because `TextStyle(package:)`
applies the prefix at construction.

The real defect was smaller: `fontFamilyFallback: ['system-ui']` was being rewritten to
`packages/njiani_core/system-ui`, a font that does not exist — a dead fallback chain, which is
worse than none because it hides a failure of the primary family. Both are fixed and guarded by
tests, but **the font was not established as the cause of the visual problem.**

If something specific still looks wrong on your device, naming the component will be faster than
me guessing.

### Files changed

**Added** — `nj_action_tile.dart`, `nj_badge.dart`, `nj_banner.dart`, `nj_stat_card.dart`,
`nj_meter.dart`, `nj_status_row.dart`, `nj_skeleton.dart`, `test/design_conformance_test.dart`.

**Rewritten** — `nj_button.dart` (sizes + blocked), `nj_upload_box.dart` (state enum),
`gallery_screen.dart` (dual-theme matrix), `gallery_app.dart` (toggle removed — both themes show
at once), `apps/*/lib/main.dart` (identity as a testable constant).

**Edited** — `nj_typography.dart` (`themeFontFamily`, plate 18px), `nj_theme.dart` (font
resolution, focus ring), `nj_otp_field.dart` (error reset), `nj_hint.dart` (13.2px),
`nj_plate.dart` (18px), `njiani_core.dart` (barrel, 37 exports).

### How to test

```sh
git pull
./tool/check.sh --fix     # clears the stale widget_test.dart, then runs everything
                          # expect: no analyzer issues, 115 tests passing

cd apps/njiani_rider  && flutter run --dart-define-from-file=../../.env.local
cd apps/njiani_driver && flutter run --dart-define-from-file=../../.env.local
```

You are on Windows, so this is **Android only** for now. The iOS code is kept correct but cannot
be built without a Mac.

| # | Step | Expected |
| --- | --- | --- |
| 1 | Launch either app | The component matrix. **Check the font first** — headings should be Bricolage Grotesque, not Roboto |
| 2 | Scroll any section | Light panel above, dark panel below, same component |
| 3 | Route board section | Yellow in **both** panels. Compare against the design |
| 4 | Buttons section | 4 variants, then disabled at 45%, loading, compact 48pt, and "Seats full" at full opacity |
| 5 | OTP section | Tap "Simulate wrong code" — boxes go red **and clear** |
| 6 | Upload section | All four states: dashed, uploading, teal done, red failed |
| 7 | Tokens section | Hex values printed under each swatch — compare with the design's swatch list |
| 8 | Rotate to landscape | Above 620pt the panels sit side by side |

**What I most want to know:** does the font render correctly (step 1), and does anything in the
dark panel disappear or go muddy (step 2)?

### What I verified, and what I could not

**Verified** — analyze clean, **115 tests** (107 core + 4 per app), including 13 design-conformance
assertions and 16 WCAG contrast checks.

**Not verified** — no Android SDK or Xcode here, so nothing has been compiled or seen on a device.
Flutter's test environment substitutes a fixed-width font, so **real Bricolage Grotesque metrics
remain unverified** — which is exactly why step 1 above is first.

### Known gaps — deliberate

| Gap | Picked up by |
| --- | --- |
| Gallery strings are English-only | **C2** |
| No screens yet — this is the component layer | **C2 onward**, one screen per sign-off |
| `NjSkeleton` loops forever, so `pumpAndSettle` never settles in tests | documented on the widget |
| Gallery ships in the release binary | **C18** |

### Sign-off

Approved 2026-09-21.

---

## C2 — `pLang`, language choice · ✅ signed off

**Goal** — the first real screen, plus the infrastructure every screen after it needs:
localisation in both languages, routing with guards, state management, and per-device
persistence.

**Credentials needed** — **none.**

### The screen

`pLang` from the design: the wordmark, a bilingual heading, two language options with Kiswahili
pre-selected, and one Continue button. Three details from the spec that look like mistakes and
are not:

| Looks odd | Why |
| --- | --- |
| The heading shows **both** languages at once | On this one screen the user cannot yet reliably read either, so picking one would be a guess. Same for the `Endelea · Continue` button |
| Tapping an option changes the screen **immediately**, before Continue | The choice is demonstrated rather than described. The subtitle switches language under your finger |
| `Kiswahili` and `English` are never translated | They are endonyms — a language's name in its own language. Identical in both `.arb` files, deliberately |

Kiswahili is pre-selected because it is the first language of the pilot corridor.

### Infrastructure this component brings

| Layer | Choice |
| --- | --- |
| **Localisation** | `flutter_localizations` + ARB. `NjStrings`, generated into `lib/src/l10n/generated` and **committed**, so a fresh clone analyses without a codegen step |
| **State** | `flutter_riverpod`, no code generation — `NotifierProvider` directly, so there is no `build_runner` step |
| **Routing** | `go_router` with a redirect guard. Sign-in (C4) and driver-approval (C6) guards join the same redirect |
| **Persistence** | `shared_preferences`, read **before the first frame** so a returning user never sees the language screen flash past |

### `confirmed` is not the same as `locale`

`LanguageState` carries both the language and whether the user actually chose it. That
distinction is the whole guard: showing Kiswahili because it is the default is not the same as a
user asking for Kiswahili, and only the second stops the screen being shown again. It is what the
spec means by *"never blocks a returning user."*

### A real accessibility bug the tests caught

At **1.3× system text scale on a small handset the screen overflowed by 189px.** The layout is
content, then a `Spacer`, then a bottom button — which is correct on a big phone and clipped on a
small one, so the Continue button became unreachable for anyone using large text.

Every screen in the design has that shape, so the fix is a shared widget rather than a patch:
**`NjScreenBody`** keeps the `Spacer` behaviour while the content fits and becomes a scroll view
the moment it does not. There is a test at the clamp ceiling.

Related: `NjianiRoot` clamps text scaling to 0.9–1.3. Past 1.3 the route board and seat counts
stop fitting, and those are the two things a driver reads at a glance.

### Files added

| File | What it is |
| --- | --- |
| `lib/src/locale/nj_locale.dart` | The two languages. Parses `en_TZ` and `en-GB` by language subtag |
| `lib/src/locale/language_store.dart` | `shared_preferences` store, plus an in-memory one for tests |
| `lib/src/locale/language_controller.dart` | Riverpod notifier: `load` / `preview` / `confirm` / `reopen` |
| `lib/src/l10n/arb/nj_en.arb`, `nj_sw.arb` | Every string, both languages, with a description on each |
| `lib/src/l10n/generated/` | `NjStrings` — committed, drift-guarded |
| `lib/src/app/nj_routes.dart` | Route paths, shared so the two apps cannot drift |
| `lib/src/app/nj_router.dart` | Router and the language guard |
| `lib/src/app/njiani_root.dart` | Shared root: theme, locale, router, `bootstrap()` |
| `lib/src/screens/language_screen.dart` | **`pLang`** |
| `lib/src/screens/placeholder_screen.dart` | Honest stand-in naming the component that will replace it |
| `lib/src/widgets/nj_option_tile.dart` | Selectable row — teal border and tint, not a 20pt radio dot |
| `lib/src/widgets/nj_screen_body.dart` | The scroll-when-needed column |

**Changed** — `apps/*/lib/main.dart` are now one line each; `apps/*/pubspec.yaml` declare
Riverpod; `tool/check.sh` gained the l10n drift guard.

**Tests added — 38 new, 153 total** across `locale_test.dart`, `language_screen_test.dart`,
`router_test.dart` and the two app suites.

### How to test

```sh
git pull
./tool/check.sh --fix     # expect: localisations up to date, no analyzer issues,
                          # 153 tests passing

cd apps/njiani_rider  && flutter run --dart-define-from-file=../../.env.local
cd apps/njiani_driver && flutter run --dart-define-from-file=../../.env.local
```

Android only while you are on Windows.

| # | Step | Expected |
| --- | --- | --- |
| 1 | Launch either app, first time | The language screen. **Kiswahili already selected** |
| 2 | Read the heading | Both lines: `Chagua lugha` above `Choose your language` |
| 3 | Tap **English** | Teal border and tint move; the subtitle changes to English **immediately** |
| 4 | Tap **Kiswahili** | It changes back. Nothing has been saved yet |
| 5 | Tap `Endelea · Continue` | The placeholder naming the next component — **C4** in the rider app, **C6** in the driver app |
| 6 | **Close the app fully and reopen** | Straight to the placeholder. The language screen does **not** appear again |
| 7 | Tap **Change language** / **Badilisha lugha** | Back to the chooser |
| 8 | Tap **Component gallery** | The C1 matrix, still reachable |
| 9 | Android Settings → Display → Font size → largest, then reopen | The screen **scrolls**; Continue stays reachable |
| 10 | Install both apps | Two icons; each shows its own next component |

**Step 6 is the one that matters** — it is the whole point of the `confirmed` flag.

### What I verified, and what I could not

**Verified** — analyze clean, **153 tests**, including the overflow case at the text-scale
ceiling and both languages rendering end to end.

**Not verified** — no Android SDK here, so nothing compiled or run on a device. In particular
**`shared_preferences` is never exercised against a real device** — every test uses the in-memory
store. Step 6 is the first time the real one runs, so if the language screen reappears after a
restart, that is where to look.

### Known gaps — deliberate

| Gap | Picked up by |
| --- | --- |
| `profiles.lang` is not written — only the device preference | **C5**, once there is an account |
| No Settings screen; Change language sits on the placeholder | later |
| Gallery strings are still English-only — it is a dev surface | not planned |
| No sign-in guard yet | **C4**, in the same redirect |

### Sign-off

Approved 2026-09-22.

---

## C3 — Database: schema, PostGIS, RLS, seed · ✅ signed off

**Goal** — the schema the whole product runs on, including the two functions
that *are* the product, with the security model that keeps passengers' data
away from drivers.

**Credentials needed** — **`SUPABASE_URL`, `SUPABASE_ANON_KEY` and
`SUPABASE_SERVICE_ROLE_KEY`, for the first time.** See `docs/CREDENTIALS.md`.

### This one I could actually run

Every component so far shipped unexecuted, because there is no Android SDK
here. This one is different: I installed **Postgres 16 + PostGIS 3.4.2 +
pg_cron** in this container, applied the migrations to a real database, seeded
it, and ran the test suite.

**47 assertions pass**, including a genuine two-connection race.

### The two functions, tested against real geometry

`match_requests_for_session()` — ten assertions, one per rule:

| Assertion | Result |
| --- | --- |
| A passenger ahead on the road is matched | ✓ |
| A passenger **behind** the driver is not | ✓ |
| A passenger going **past** the driver's destination is not | ✓ |
| A passenger 2 km off the road is not | ✓ |
| A boda request is not shown to a bajaj driver | ✓ |
| An expired request is not matched | ✓ |
| A full vehicle sees nothing | ✓ |
| Nearest ahead is first — **never the highest price** | ✓ |
| Distance is measured **along the road**, not straight-line | ✓ |
| Another user passing this session id gets an empty feed | ✓ |

`accept_ride_request()` — raced for real. Two separate psql connections, two
different drivers, one passenger, 0.3 s apart:

```
driver A: t|ok
driver B: f|already_taken
```

B genuinely blocked on A's row lock, then re-evaluated its `WHERE status =
'open'` against the committed row and correctly found nothing. Six invariants
checked afterwards: claimed exactly once, exactly one seat row, exactly one
driver lost a seat, the other kept all three, the agreed price was copied onto
the seat, and the seat belongs to the winning session.

### Two real bugs the tests found

**1. A cancelled seat stranded the passenger permanently.** `trip_seats` had
`UNIQUE(request_id)`. When a driver released a seat, the request correctly went
back on the road — visible to every driver, and **impossible for any of them to
take**, because the cancelled row still held the unique slot. The first driver
cancellation in production would have produced a request that looked live and
could never be claimed.

Fixed with a partial unique index: at most one *live* seat per request, with
cancelled rows kept as history.

**2. An enum cast in `release_trip_seat`.** A `CASE` returning `text` into a
`request_status` column. It would have failed the first time anyone cancelled.

Neither was reachable by reading the code carefully. Both took executing it.

### Security model — 15 assertions

The two that carry the weight:

- **A driver cannot read `ride_requests` at all.** They hold no policy on that
  table; the feed comes only from `match_requests_for_session()`, which is
  `SECURITY DEFINER` and scoped to their own online session. A driver cannot
  enumerate passengers, cannot see outside their corridor, and sees nothing
  while offline. Verified by querying the table as a driver: **0 rows.**
- **A driver cannot approve themselves.** `drivers.status` is protected by
  column-level `GRANT`, because RLS operates on rows and cannot protect a
  single column. Verified: the update is refused, while editing their own plate
  still works.

Also checked: passengers cannot read driver sessions or the admin list, signed-
out users see nothing, a rejection without a reason is refused, approval
without a licence on file is refused, a bajaj session cannot claim four seats,
and a passenger cannot hold two open requests.

### Files added

```
supabase/
├── migrations/        8 files — extensions, enums, reference data, identity,
│                      matching tables, the two functions, RLS, cron
├── seed.sql           Ubungo <-> Kimara: 2 routes, 20 stages, 180 price bands
├── tests/             47 assertions + run.sh
└── README.md          how to apply and test, including a no-Docker path
```

### How to test

**You need a Supabase project now.** Two paths, both in `supabase/README.md`:

**Easiest on Windows — hosted, no Docker:**

1. Create a free project at supabase.com
2. Database → Extensions: enable **postgis** and **pg_cron** (the schema will
   not apply without them)
3. `supabase link --project-ref <ref>` then `supabase db push`
4. Then seed, and run the tests with the connection string from
   Settings → Database:
   ```sh
   DATABASE_URL="postgresql://..." ./supabase/tests/run.sh
   ```

**Fully local** — `supabase start` then `supabase db reset`, needs Docker
Desktop.

| # | Step | Expected |
| --- | --- | --- |
| 1 | Apply the migrations | All 8 apply with no errors |
| 2 | Run `seed.sql` | `2 routes, 20 stages, 180 price bands, 8.8 km` |
| 3 | Studio → Table editor → `stages` | Twenty rows, ten per direction, `seq` ascending |
| 4 | Run `./supabase/tests/run.sh` | **47 assertions passed** |
| 5 | Watch the race line | `driver A: t\|ok` and `driver B: f\|already_taken` |
| 6 | Studio → SQL editor, select from `price_bands` | Ubungo→Kimara Korogwe is 1,000–1,500 |

Nothing in the apps changes yet — C3 is schema only. The apps still run C2.

### ⚠ The coordinates are not surveyed

`seed.sql` uses plausible positions along Morogoro Road. They are good enough
to develop against and **are not measured**.

This matters more than it sounds: a stage placed 400 m from where people
actually stand falls outside the 300 m corridor, and the matching query returns
nothing while looking perfectly healthy. There is no error to see.

Before launch, walk the corridor and take a GPS reading at each stage. That
same visit is when the price bands get real numbers — everything except the two
anchors from the pitch deck is interpolated by distance and marked as a
placeholder.

### What I verified, and what I could not

**Verified** — all 8 migrations apply to an empty database; the seed loads;
47 SQL assertions pass, including real concurrency, on Postgres 16 / PostGIS
3.4.2 / pg_cron 1.6.

**Not verified** — this ran against **local Postgres with a stub for Supabase's
`auth` schema, `auth.uid()` and the `anon`/`authenticated`/`service_role`
roles**. Supabase's real auth, its Realtime publication, and its storage
buckets are untested. Step 1 on your project is the first time these meet the
real thing.

Also untested: `pg_cron` schedules are created but I have not watched one fire
on a one-minute cadence.

### Known gaps — deliberate

| Gap | Picked up by |
| --- | --- |
| No Dart client, no repositories | **C4** onward |
| Realtime publication not configured | **C9**, where the live feed needs it |
| Storage bucket for licence photos not created | **C6** |
| Only the Ubungo↔Kimara corridor is seeded | more routes post-pilot |
| Boda price bands duplicate the bajaj ones | needs observed data |

### Fix, 2026-10-22 — the migrations failed on a real project

**Symptom**, on `supabase db push`:

```
ERROR: type "geography" does not exist (SQLSTATE 42704)
Hint: This type may be defined in a schema that's not in your search_path.
```

**Cause, and why my tests missed it.** Supabase installs extensions into an
`extensions` schema, which is **not** on the default search_path. My local
harness installed PostGIS into `public`, where a bare `geography(Point, 4326)`
resolves fine. So the harness tested a layout no real project has, and the
47 passing assertions said nothing about the thing that actually broke.

That is the more useful lesson than the fix: **a local stand-in that differs
from production in any way will eventually certify a bug.** The harness now
installs PostGIS into `extensions` and creates the same three roles, so it
mirrors a hosted project rather than a convenient one — and running it
reproduced the failure immediately.

**Fixes**

1. Every migration, function, seed and test that touches PostGIS now begins
   `set search_path = public, extensions;`. Chosen over schema-qualifying each
   type because it keeps the DDL readable and works whichever schema the
   extension ended up in.
2. `supabase/config.toml` added — the CLI needs it to link or push at all, and
   it was missing. It sets `extra_search_path = ["public", "extensions"]` so
   PostgREST can read a `geography` column over the API: the same problem on
   the other side, which would have bitten next.
3. `verify_jwt = false` for `send-sms-hook` is now declared in config rather
   than being a flag to remember on every deploy.
4. The extensions migration creates the `extensions` schema explicitly and
   grants the API roles usage on it.
5. `./tool/check.sh` runs the SQL suite whenever `DATABASE_URL` is set, so the
   database is checked by the same command as everything else.

**Verified** — a fresh database built the way Supabase builds one: all 8
migrations apply, the seed loads, **47 SQL assertions pass**.

### Sign-off

Approved 2026-10-21. Supabase credentials added. Migrations corrected
2026-10-22 for the `extensions` schema.

---

## C4 — `pPhone` + `pOtp`, phone and SMS code · 🧪 awaiting your test

**Goal** — a real session. Supabase Auth phone sign-in, with the code delivered
through Beem Africa by a Send-SMS hook.

**Credentials needed** — Supabase URL and key (you have these). **No SMS
credential is required to test**: `SMS_PROVIDER=console` writes the code to the
function log.

### ⚠ One thing in the design cannot be built as drawn

**The design shows 4 OTP boxes. Supabase Auth will not issue a code shorter
than 6 digits** — its configurable range is 6 to 10. Four boxes could never be
filled by a code it actually sent.

I built it with **6**, as a single constant (`kOtpLength`), and the security
side of that constraint happens to be the right way round: an SMS code is the
only authentication factor in this app, and six digits is a million
combinations against four digits' ten thousand.

If you want 4 regardless, the only routes are self-hosting GoTrue or issuing
codes ourselves in an Edge Function — the second means minting sessions by
hand, which is the kind of home-made auth that should not exist in a
ride-hailing app. **My recommendation is to keep 6 and update the design.**
Changing it back is one constant either way.

### How the pieces divide

Supabase Auth **generates** the code, **decides** whether a submitted one is
correct, **caps the attempts** and **issues the session**. The Edge Function
only **delivers** the message. Beem never learns whether a code was accepted,
and nothing in the app can authenticate anybody.

Beem also sells a hosted OTP product that verifies codes itself. Using it would
mean bridging Beem's verdict into a Supabase session by hand — so this uses
Beem as pure transport instead.

**The Beem request shape was confirmed against Beem's own client library, not
from documentation:**

```
POST https://apisms.beem.africa/v1/send
Authorization: Basic base64(api_key:secret_key)
{ "source_addr": "NJIANI", "schedule_time": "", "encoding": 0,
  "message": "...", "recipients": [{"recipient_id": 1,
  "dest_addr": "255712345678"}] }
```

### Three real bugs the tests found

**1. A wrong code crashed the screen.** `NjOtpField` cleared its boxes from
`didUpdateWidget`, which runs during build, and the clear called `onChanged` →
`setState` on the parent. That threw *"setState called during build"* and
blanked the subtree — so entering a wrong code destroyed the screen that was
meant to report it. The reset is now deferred to a post-frame callback.

**2. The error wiped itself.** Clearing the boxes fired `onChanged('')`, which
the screen treated as the user editing and used to clear the failure — in the
same frame the message appeared. The user was told nothing about why their code
failed. Only a keystroke clears it now.

**3. Going back and re-sending burned a second SMS.** `sendCode` had no resend
guard, so leaving the code screen and pressing Send again paid for another
message. Re-sending to the *same* number inside the window now goes straight
back to the code screen; a *different* number still sends, because that is a
corrected typo.

### Also added: an injectable clock

`clockProvider` replaces direct `DateTime.now()` calls. It made the resend
countdown testable without waiting a minute — and caught a real inconsistency:
`OtpScreen` was computing the countdown from `DateTime.now()` while the
controller stamped `codeSentAt` from the provider, so the display could
disagree with the guard that actually gates the resend. C9's request expiry and
C11's ETA need the same seam.

### Files added

| File | What it is |
| --- | --- |
| `lib/src/auth/tz_phone.dart` | The one place that decides `0712…`, `712…`, `+255 712…` and `255712…` are the same person |
| `lib/src/auth/auth_failure.dart` | A closed set of reasons, because each needs different words in two languages |
| `lib/src/auth/auth_repository.dart` | Interface, Supabase implementation, and an unconfigured one that names the missing key |
| `lib/src/auth/fake_auth_repository.dart` | In `lib/`, not `test/`, so both apps and a dev build can walk the flow for free |
| `lib/src/auth/auth_controller.dart` | The state machine, `kOtpLength`, `kResendWindow`, `clockProvider` |
| `lib/src/data/supabase_client.dart` | Init that degrades instead of throwing when there are no credentials |
| `lib/src/screens/phone_screen.dart` | **`pPhone`** |
| `lib/src/screens/otp_screen.dart` | **`pOtp`** |
| `supabase/functions/send-sms-hook/` | The Beem delivery hook + its README |

**Changed** — `nj_router.dart` (the auth gate joins the language gate in one
redirect), `nj_otp_field.dart` (paste, autofill, deferred reset), `nj_button.dart`
(a 44pt chip size for the Back affordance), `placeholder_screen.dart` (sign out,
so the flow can be re-walked without reinstalling), `tool/check.sh` (the l10n
guard now compares before/after regeneration rather than against git — it was
failing on every newly added string).

**Tests added — 68 new, 221 total.**

### How to test

You can now deploy to iOS as well, so both platforms are in scope.

```sh
git pull
flutter pub get
./tool/check.sh --fix     # expect: 221 tests passing
```

**First, the Supabase side** (`supabase/functions/send-sms-hook/README.md` has
the detail):

1. Authentication → Providers → **Phone**: enable
2. Authentication → Hooks → **Send SMS hook**: copy the signing secret
3. ```sh
   supabase secrets set SMS_PROVIDER=console SEND_SMS_HOOK_SECRET='v1,whsec_...'
   supabase functions deploy send-sms-hook --no-verify-jwt
   ```
4. Point the hook at the deployed URL

Then run the app:

| # | Step | Expected |
| --- | --- | --- |
| 1 | Launch, choose a language, continue | **The phone screen**, not the placeholder |
| 2 | Look at the field | `+255` is fixed on the left and cannot be deleted |
| 3 | Type 8 digits | Send code stays dimmed |
| 4 | Type the 9th | It enables |
| 5 | Clear it, type `0712345678` | Still enables — the leading zero is not a digit of the number |
| 6 | Tap **Send code** | Spinner, then the code screen. Tapping twice must not send twice |
| 7 | `supabase functions logs send-sms-hook` | A line with the 6-digit code |
| 8 | Type a **wrong** code | All six boxes go red, **clear**, and the message stays visible. **The screen must not blank** |
| 9 | Type the real code | Straight into the app |
| 10 | Tap **Sign out**, then sign in again | Back to the phone screen and through again |
| 11 | On the code screen, watch the countdown | `Resend in 0:59` ticking down, then a tappable **Resend code** |
| 12 | Tap **Back** / **Wrong number?** | Phone screen, **with the number still filled in** |
| 13 | Turn airplane mode on, tap Send code | "No connection", and the number is kept |

**Step 8 is the one I most want confirmed** — it is where the crash was.

### Switching to real SMS

Only when the `NJIANI` sender ID is approved:

```sh
supabase secrets set SMS_PROVIDER=beem BEEM_API_KEY=... BEEM_SECRET_KEY=... \
  BEEM_SENDER_ID=NJIANI
```

Set the rate limits in Authentication → Rate limits first. That is the only cap
that cannot be bypassed by reinstalling the app, and every send costs money.

### What I verified, and what I could not

**Verified** — analyze clean, **221 tests**, including every state the design
spec lists for both screens, phone normalisation across eight input forms, the
paste-and-autofill path, and the resend countdown against an injected clock.

**Not verified, and this is the significant gap for C4** — I have no Supabase
project and no Beem account, so:

- **The Send-SMS hook has never executed.** Its webhook-signature check, its
  Beem request and its error handling are all unrun. The Beem payload shape is
  confirmed from Beem's own client library, but confirmed-by-reading is not
  the same as a 200 response.
- **No real code has been sent or verified.** Every test uses
  `FakeAuthRepository`; `SupabaseAuthRepository` is untested against real
  Supabase, including how its error messages map onto `AuthFailure`. If a wrong
  code shows "Something went wrong" instead of "That code is not right", the
  classifier in `auth_repository.dart` is where to look — send me the message
  text and I will match it.
- Still no device build here, so nothing has been seen on a screen.

### Known gaps — deliberate

| Gap | Picked up by |
| --- | --- |
| `profiles.lang` is still not written from the device choice | **C5** |
| No driver-approval gate in the redirect | **C6** |
| The SMS body is bilingual in one message rather than per-profile language | needs `profiles.lang` from C5 |
| No SMS cost dashboard; the function logs one line per send | **C16** |

### Fix, 2026-10-21 — a backend error was reported as a bad phone number

**Symptom.** A valid nine-digit number showed *"Enter 9 digits, without the
leading zero."* while the Send code button stayed enabled.

**Cause.** Not the counting. `TzPhone` parsed the number correctly — verified
by reproducing the exact input. The error came from the server, through this:

```dart
if (message.contains('phone')) return AuthFailure.invalidPhone;
```

Supabase replies *"Phone logins are disabled"* when the Phone provider is off
or the SMS hook is not wired. That contains "phone", so it was mapped to a
digit-count error — blaming the user's number for a project setting, and
sending them to correct something that was already right.

**Fixes**

1. **Send and verify are classified separately.** A send failure can never be
   about the digits, because the client checks them first. The only outcomes
   are rate limit, provider disabled, or unknown. `invalidPhone` is now set
   *only* by our own parsing.
2. **`AuthFailure.providerDisabled`** added, with a message naming the
   dashboard setting to change rather than the user's number.
3. **The provider's own message is kept** on `AuthState.failureDetail` and
   shown on screen in debug builds as `Server said: …`. A classifier that
   discards the real message cannot be debugged, which is why this took a
   screenshot to find.
4. **`maxLength` raised from 13 to 20.** `+255 712 345 678` is sixteen
   characters, so pasting one was silently truncated and left the button
   disabled with nothing to explain it.

**Tests added — 14**, including the exact regression: a send failure whose
message contains "phone" must never render the digit-count error, and all
three forms of a real number must enable the button.

### Fix, 2026-10-21 (2) — `Gateway Timeout` from the SMS hook

**Symptom.** With the debug line now working, the real cause showed:
`Server said: {"message":"Gateway Timeout"}`.

**What that means.** Supabase called the hook and got nothing back. It is not
an app problem and not a phone-number problem.

**Cause.** My Edge Function used two Node-isms that Deno does not guarantee:
`import { createHmac, timingSafeEqual } from 'node:crypto'` and a bare
`Buffer`, which **is not a global in Deno at all**. A module that fails to
boot never answers, and Supabase reports an unanswered hook as
`Gateway Timeout` — an error that says nothing about its own cause.

**Fixes**

1. **The function has no imports.** `crypto.subtle`, `atob`, `btoa`,
   `TextEncoder`, `AbortSignal.timeout` — all Web standards present in Deno.
   This removes the whole class of boot failure and keeps cold starts inside
   the hook's short timeout.
2. **A `GET` health check.** `curl https://<ref>.supabase.co/functions/v1/send-sms-hook`
   reports the provider and which secrets are present, never their values.
   **If that does not answer, the function is not deployed** — which is the
   one thing no amount of looking at the app reveals.
3. **The Beem call has a 4-second timeout**, under Supabase's hook limit, so a
   slow gateway returns a real error instead of being cut off as another
   timeless timeout.
4. **Entry logging** so the logs show whether the function was reached at all.
5. **Errors use the shape auth hooks expect** (`{error: {http_code, message}}`),
   so Supabase can report them rather than treating the reply as malformed.

**Verification.** The signature code is pure Web Crypto, which means it can be
tested without Deno: `tool/check-sms-signature.mjs` checks it against an HMAC
computed independently with Node's own `createHmac`. **11 checks**, now part
of `./tool/check.sh` — correct signature accepted, rotation header accepted,
wrong signature, tampered body, tampered timestamp, wrong version, empty
header and malformed secret all rejected, and the compare is constant-time.

Getting this wrong in either direction matters: too strict rejects real
deliveries, too loose lets anyone who learns the URL spend Njiani's SMS
credit.

### Fix, 2026-10-22 (2) — a misconfiguration leaked a database password

**Symptom.** `Server said: Invalid argument(s): Unsupported scheme
'postgresql' in URI postgresql://postgres:<password>@db.<ref>.supabase.co:5432/postgres/auth/v1/otp`

**Cause.** `SUPABASE_URL` held the **database connection string** instead of
the API URL. The client appended `/auth/v1/otp` to it and complained about the
scheme — quoting the whole URI, password included, into a line that then
travelled into a screenshot.

Two separate failures, and the second is the serious one.

**1. Nothing checked the value.** The dashboard offers two similar-looking
strings and only one belongs in `SUPABASE_URL`. `AppConfig.supabaseUrlProblem`
now rejects a `postgres://` scheme, a non-https URL, and any URL carrying a
username and password — each with a message naming the setting and the fix.
`initSupabase` refuses rather than handing a bad value to the SDK, and the
reason is carried to the screen so a misconfiguration names itself.

**2. A diagnostic printed a credential.** `redactSecrets` now masks
user:password in any URI, JWTs, `sb_publishable_`/`sb_secret_` keys,
`whsec_` signing secrets and bearer tokens — everywhere a provider message is
shown or a config value is displayed. It **masks rather than hides**, so
`postgresql://postgres:••••••@db…` still reveals the mistake while revealing
nothing else. Hiding the value outright would have made the pasted connection
string invisible, which is the very thing that needed seeing.

**Also fixed: the SQL runner reported green on zero assertions.** Postgres was
down during one run; psql's lowercase `psql: error:` slipped past a grep
looking for `ERROR`, so four files that never executed were reported as
passing. The runner now checks psql's exit code and **treats zero assertions
as a failure** — an empty run means the file did not execute, and calling that
green is worse than having no suite.

**Tests added — 15**, covering redaction of every credential shape, that a
correct API URL is shown in full, and that a pasted connection string shows
its host and scheme but not its password.

### Sign-off

_Awaiting your test._

---

## C5 — Profile, account language, session persistence · 🧪 awaiting your test

**Goal** — the account record behind a session: read it, keep its language in
step with the device, and confirm the session survives a restart.

**Credentials needed** — the Supabase ones from C3. No new ones.

### Why `profiles.lang` exists at all

The device already knows the language — it is chosen on the very first screen,
before anyone signs in (C2). The account copy exists for the things composed
**on the server**, where the device preference is not available: the SMS body
and, at C13, push notifications.

**The device wins.** It is the only choice that can be right at the moment it
is needed, so sign-in mirrors it onto the account, and a later language change
follows through. The account copy is never read back to override the device.

Written only when the two actually differ — this runs on every sign-in, and a
no-op round trip is still a round trip on a metered connection.

### A race worth handling

`handle_new_user` creates the `profiles` row on the auth server, so a client
can out-race it by a few hundred milliseconds on a first sign-in. Failing
there would send a brand-new user back to the phone screen for no reason, so
the load retries. The retry policy is injectable (`ProfileLoadPolicy`) and
turned off in tests.

### A real leak the tests caught

The first retry used `Future.delayed`, which left **a live timer running after
the provider was disposed**. Flutter's test binding fails on that, and it is
right to: a timer with no owner is work nobody is waiting for. In the app it
would have been an invisible wake-up every time a signed-out user's profile
provider was torn down.

The wait is now a `Timer` cancelled on `ref.onDispose`, and the loop checks
for disposal between attempts.

### Files added

| File | What it is |
| --- | --- |
| `lib/src/profile/profile.dart` | The account record. `fromRow` tolerates an unknown language rather than crashing a returning user out of the app |
| `lib/src/profile/profile_repository.dart` | Interface, Supabase implementation, and an in-memory fake |
| `lib/src/profile/profile_controller.dart` | Load, retry, language sync, `ProfileLoadPolicy` |

**Changed** — `placeholder_screen.dart` now shows the account, so C5 is
visible rather than merely claimed: the verified phone, the device language,
and whether the account copy agrees (`✓` or `out of step`).

**Tests added — 13**, covering the row mapping, the language mirror in both
directions, that nothing is written when the two already agree, the
trigger race, a failed sync leaving the session intact, and sign-out
clearing the profile.

### How to test

```sh
git pull
./tool/check.sh --fix
cd apps/njiani_rider && flutter run --dart-define-from-file=../../.env.local
```

| # | Step | Expected |
| --- | --- | --- |
| 1 | Sign in | The placeholder shows your **verified phone number** |
| 2 | Look at Device / Account | Both name the same language, with a **✓** |
| 3 | Tap **Change language**, pick the other one, continue | Both rows change, still **✓** |
| 4 | In Supabase → Table editor → `profiles` | Your row's `lang` matches what you picked |
| 5 | **Force-close the app and reopen** | Straight back in. No phone screen, no code |
| 6 | Tap **Sign out** | Phone screen. The account row stays in `profiles` |
| 7 | Sign in again | Same profile, same phone number |

**Step 5 is the one that matters** — it is session persistence, and the first
time `supabase_flutter`'s own storage is exercised on a device rather than in
a test.

### What I verified, and what I could not

**Verified** — analyze clean, **263 Flutter tests**, 47 SQL assertions, 11
signature checks.

**Not verified** — `SupabaseProfileRepository` has never run against a real
database. Specifically untested: that the RLS policy lets a user update their
own `lang` (the policy exists and is tested in SQL, but not through
PostgREST), and that session restore works on a device. Steps 4 and 5 are the
first real exercise of both.

### Known gaps — deliberate

| Gap | Picked up by |
| --- | --- |
| `display_name` is written but never set | **C6**, driver sign-up |
| The SMS body is still bilingual rather than per-profile | needs the hook to read `profiles.lang` — a C6 follow-on |
| No profile screen; the placeholder stands in | later |

### Sign-off

_Awaiting your test._

---

## Tooling, 2026-10-22 — the Providers form, and two false greens in the harness

Not a component. Three things came out of your screenshot of
Authentication → Providers → Phone.

### The form demands an SMS provider that will never be called

You are right that it cannot be saved without one: the dropdown has no "none"
and the chosen provider's credential fields turn required. None of those
credentials is ever read — an enabled Send SMS hook means Supabase hands the
code to our own function and never touches the configured provider.

`supabase/config.toml` now declares `[auth.hook.send_sms]`, so the hook, the
OTP length, the expiry and the resend window can all be set with
`supabase config push` instead of through a form that validates fields nothing
will use. `supabase/README.md` documents that route and the placeholder-
credentials alternative, including why the placeholders are only harmless
while the hook stays enabled.

**I could not verify which route Supabase intends.** supabase.com and the docs
mirror are both DNS-blocked from this container, so what is written down is
reasoning from the form's own behaviour plus our config, not a citation.

Two settings in that form are worth changing while you are in it:

| Field | Was | Set to | Why |
| --- | --- | --- | --- |
| SMS OTP Expiry | 60s | **300s** | 60s is identical to our resend window, so a code expires at the exact moment the app offers a new one. Anyone who switches to their SMS app, reads the code and comes back is racing it. |
| SMS OTP Length | 6 | leave at 6 | Confirms D19. The platform will not go lower, which is why the app has six boxes and not the design's four. |

**SMS Message** in that form is ignored while the hook is on — our function
composes the message itself, in both languages. Noted in `config.toml` and the
README so nobody edits it expecting an effect.

### False green 1 — a skipped SQL suite reported as a pass

`./tool/check.sh` ran the SQL suite only when `DATABASE_URL` was set, and said
nothing at all when it was not. It then printed **All checks passed.** A run
with no database verified no schema, no RLS, and neither core function, and
looked identical to a run that verified all three.

This is the same family as the bug fixed in `tests/run.sh` on 2026-09-30,
where zero assertions counted as a pass. Fixed the same way — by making the
absence loud:

```
==> database (SQL suite)
    SKIPPED -- DATABASE_URL is not set
    The schema and both core functions are NOT verified by this run.

All checks passed, except the SQL suite, which was skipped.
```

### False green 2 — the local database was hand-built from memory

The harness this container had been using was set up by hand, so it did not
survive the container being rebuilt, and the SQL suite went from 47 assertions
to skipped without anything being wrong with the SQL. Rebuilding it by hand
also meant rebuilding the decision about **where PostGIS goes** — the decision
that was wrong the first time, passed locally, and failed on your project with
`type "geography" does not exist`.

So it is a script now: `./tool/dev-db.sh`, with everything Supabase provides
before our first migration runs in
`tool/dev-db/supabase-prelude.sql` — PostGIS in `extensions`, the three roles,
the table grants that let RLS rather than `permission denied` decide the
answer, and `auth.users` with `auth.uid()`.

That file is **not a migration** and says so at the top; Supabase already owns
all of it. It has exactly one deliberate deviation, marked in place:
`auth.uid()` also honours the `njiani.test_uid` GUC the suite uses to say who
it is acting as. That one is unavoidable — impersonation on the real project
comes from a signed JWT the suite cannot mint — so the JWT claim is read first
and the test GUC only as a fallback.

Rebuilt from scratch, the suite returns **47 assertions**, the same count as
before, which is the evidence that the prelude reproduces what was there.

### Files

| File | Change |
| --- | --- |
| `supabase/config.toml` | `[auth.hook.send_sms]`; `otp_exp = 300`, `otp_length = 6`, `max_frequency = "60s"`; corrected the Providers note |
| `supabase/README.md` | the Providers form, and how to build a local database the migrations apply to |
| `tool/check.sh` | a skipped SQL suite now says so, in the stage and in the summary |
| `tool/dev-db.sh` | **new** — reproducible local database |
| `tool/dev-db/supabase-prelude.sql` | **new** — what Supabase provides, and the one deviation |
| `docs/CREDENTIALS.md` | the OTP-expiry note |

### Verified

Analyze clean, **263 Flutter tests**, **47 SQL assertions**, 11 signature
checks — with the database present, and the skip path checked separately by
unsetting `DATABASE_URL`.

Still unverified, unchanged from C4: the Edge Function has never executed
against real Supabase or Beem.

---

## C6 — Driver sign-up, licence upload, review, approval · 🧪 awaiting your test

Three screens — `dSignup`, `dPending`, `dRejected` — plus the gate that decides
which of them a driver sees, and the two SQL functions that are the only ways
`drivers.status` moves.

### Credentials

| Key | Needed for | Status |
| --- | --- | --- |
| `SUPPORT_PHONE` | the "Call Njiani" buttons | **blank — you add it** |

Full international form: `SUPPORT_PHONE=+255XXXXXXXXX`. **Left blank the button
is hidden, not broken** — a button that dials nothing is worse than no button
to a driver who has just been told they cannot work.

Nothing else. The bucket is created by a migration, and the camera needs no
key.

### The gate, and why it is one function

`drivers.status` is the only thing standing between an unchecked licence and a
passenger getting into a stranger's vehicle. C3 already held the column back
from `authenticated` by GRANT — RLS cannot protect a single column — and the
SQL suite asserts it:

```
✓ a driver cannot approve themselves           42501
✓ a driver cannot file an application for someone else
✓ a driver cannot review anyone
✓ a driver can still correct their own plate   (null -- allowed)
```

If the first of those ever passes the other way, every other check in the file
is decoration. It is written as an exact SQLSTATE rather than "was it
refused?", so it cannot go green because something unrelated broke.

The client side of the same question is `driverGateFor()` — one function, so
the router's redirect and the pending screen cannot disagree about what
`suspended` means. Its most important case is the dull one:

```dart
AsyncError() => DriverGate.unknown,
```

A failed read holds position. Sending an approved driver back to a blank
sign-up form because their data dropped out at a stage is the worst outcome
available on this screen, so an error waits rather than guessing.

`DriverStatus.parse` leans the same way: an unrecognised status reads as
`pending`, never `approved`. If a future release adds a state, an old binary
says "under review" — wrong, but safe.

### What a rejected driver can do, and what they cannot

The design promises: *"Replace the photo and you go back in the queue — you
don't start again."* That promise needs a status transition the driver is not
allowed to make, so it gets a `security definer` function —
`resubmit_driver_licence()`, `rejected` → `pending`, nothing else:

- Scoped to a **rejected** row. A pending driver can already replace the photo
  with a plain UPDATE, since `licence_path` is in the C3 update grant, and does
  not need a privileged function to do it.
- **Refuses a path outside the caller's own folder.** Without that check a
  driver could point their row at another driver's photo and be approved on
  someone else's licence.
- Leaves the vehicle, plate and colour exactly as they were, which is what
  makes the rejection screen's checklist — phone **Verified**, vehicle
  **Accepted**, photo **Rejected** — a true statement rather than a decoration.

`review_driver()` is the other half: the admin decision, with the reason
required. The table has a CHECK that enforces it; the function raises a
sentence a person can read instead of a constraint name. It also refuses
`pending` as a target, so the admin path and the driver path cannot be
confused for each other.

### The licence bucket

Private, 5 MB cap, image-only MIME allow-list — all three enforced by Storage
before a byte is written, so they are limits rather than client-side
courtesies. The path shape is the load-bearing part:

```
<auth.uid()>/licence.jpg
```

The first folder segment **is** the owner, which is what makes "your own
object" expressible as an RLS policy at all —
`(storage.foldername(name))[1] = auth.uid()::text`. A flat
`licence-<uuid>.jpg` would leave nothing for a policy to match on.

**No DELETE policy, deliberately.** The photo is the evidence behind an
approval decision, so a driver cannot erase it after the fact and an admin
cannot do it by accident from the app. Deletion is a retention job, with the
service role, and belongs at C17.

A fixed filename with upsert rather than a timestamp: a driver who retakes the
photo four times leaves one object, not four. Nothing points at an old
version, so keeping them would only mean more of a licence photo sitting in a
bucket than necessary.

### The upload goes first, on its own

From the design: *"upload failed → 'Photo didn't upload. Your details are
saved.' — retry only the photo."* So the photo uploads before Submit is ever
enabled, as its own step, and a failure sets the upload box to `failed` while
leaving the typed details untouched. The test asserts exactly that:

```dart
expect(find.text('Juma Hassan'), findsOneWidget);
expect(find.text('T 999 ZZZ'), findsOneWidget);
```

Three states that are easy to collapse into one and should not be:

| What happened | What the box says |
| --- | --- |
| Upload failed | "Photo didn't upload. Your details are saved." |
| Photo too large, or not an image | "That photo was too large or not a picture. Take a new one with the camera." |
| Driver backed out of the camera | nothing — returns to empty, or stays done |

The middle one needs its own wording because "didn't upload" tells a driver to
try again with the same photo, which will fail again. The third is not a
failure, so nothing says it is.

The camera caps the longest edge at 1600px on the way out. A modern phone
produces 4–6 MB a shot, over the bucket's limit as often as not, and every
byte is on a driver's own data bundle. 1600px is far more than a person needs
to read a licence number.

### A third, from reading my own diff

The pending screen had a `RefreshIndicator` wrapped around `NjScreenBody`,
which is always a `SingleChildScrollView` — so it compiled, looked right, and
would have done nothing. `NjScreenBody` used `ClampingScrollPhysics`, and
without an overscroll there is no gesture for a `RefreshIndicator` to
recognise. The pull would have worked only on a phone small enough for the
content to overflow, which is the opposite of useful.

`NjScreenBody` takes `physics` now, and this screen passes
`AlwaysScrollableScrollPhysics`. The test flings the screen rather than
tapping anything, because tapping would have passed either way.

### And a fourth, which the database found

`SupabaseDriverRepository.submit()` used `upsert`, which is the obvious call
and is wrong here. PostgREST builds an upsert as

```sql
on conflict (profile_id) do update set profile_id = excluded.profile_id, ...
```

— the conflict target goes in the SET list, and `profile_id` is deliberately
not in C3's update grant. So the moment a row already existed it failed with
`permission denied for table drivers`, which is precisely the retry case:
submit wrote the row, the reply never came back, the driver taps Submit again.

It is an insert, then an update of the mutable columns if the row is already
there. The tempting alternative was to add `profile_id` to the update grant —
widening a grant on a primary key to save one round trip — so there is now an
assertion whose whole job is to stop that:

```
✓ a PostgREST-style upsert is refused, which is why the client does not use one
✓ the update the client does instead is allowed
```

I found this by running what PostgREST would send against the local database,
rather than by reading the client's docs. Nothing in the Dart tests could have
caught it: the fake repository has no column privileges to violate.

### Two bugs the tests found

**The display name was being dropped.** `ProfileController.setDisplayName`
returned early when the profile had not loaded yet — and driver sign-up can
reach it while `build()` is still in flight. The write now goes first and the
local state update second, which is the right order anyway: the write is the
point, the optimistic update is the optimisation. Symptom if it had shipped: a
passenger seeing an unnamed driver at C10, long after there was anything to
connect it to.

**A returning driver saw a blank phone number.** `AuthState.phone` is only set
by typing a number in the current session, so a driver who signed in
yesterday, closed the app and came back to finish signing up had a session and
no number to show. It reads `profiles.phone` first now — the durable record —
and falls back to the auth state for the few hundred milliseconds on a
brand-new account before that row is readable.

Neither was reachable from the screens as designed; both are reachable in a
week of real use.

### What you have to add to Xcode once

`Info.plist` carries the English camera prompts and is committed. The
Kiswahili ones are in `ios/Runner/sw.lproj/InfoPlist.strings`, and **a
`.lproj` folder only ships if it is a member of the `Runner` target** — a
checkbox, not something a file on disk can do by itself.

Open `apps/njiani_driver/ios/Runner.xcworkspace`, drag `en.lproj` and
`sw.lproj` into the `Runner` group, tick **Runner** under *Add to targets*.

Until then the permission prompt is English for everyone. It is the one
user-facing string in the project the both-languages rule does not reach from
the Dart side, because iOS reads it from the bundle rather than from our
`.arb`. Nothing crashes either way.

### Files added

| File | What it is |
| --- | --- |
| `supabase/migrations/20261026000100_storage_licences.sql` | the private bucket and its policies |
| `supabase/migrations/20261026000200_driver_review.sql` | `review_driver`, `resubmit_driver_licence`, realtime on `drivers` |
| `supabase/tests/05_driver_review_test.sql` | 33 assertions on the gate, the grants and the bucket |
| `packages/njiani_core/lib/src/driver/driver.dart` | `Driver`, `DriverApplication`, `VehicleType`, `VehicleColour`, `DriverStatus` |
| `packages/njiani_core/lib/src/driver/driver_repository.dart` | the table, the bucket, the RPC, and a fake |
| `packages/njiani_core/lib/src/driver/driver_controller.dart` | the row, the realtime subscription, and `driverGateFor` |
| `packages/njiani_core/lib/src/driver/licence_camera.dart` | `image_picker` behind an interface, plus a fake |
| `packages/njiani_core/lib/src/screens/driver_signup_screen.dart` | `dSignup` |
| `packages/njiani_core/lib/src/screens/driver_pending_screen.dart` | `dPending`, and the suspended state |
| `packages/njiani_core/lib/src/screens/driver_rejected_screen.dart` | `dRejected` |
| `packages/njiani_core/lib/src/util/support_call.dart` | the `tel:` link |
| `packages/njiani_core/test/driver_test.dart` | 40 tests across the three screens and the models |
| `apps/njiani_driver/test/platform_config_test.dart` | the plist and manifest keys Dart cannot reach |
| `apps/njiani_rider/test/platform_config_test.dart` | the same, mostly as negative assertions |
| `apps/njiani_driver/ios/Runner/{en,sw}.lproj/InfoPlist.strings` | the camera prompt, both languages |

### Files changed

| File | Change |
| --- | --- |
| `packages/njiani_core/lib/src/app/nj_router.dart` | the third gate, driver app only |
| `packages/njiani_core/lib/src/app/nj_routes.dart` | three routes and the `driverGate` set |
| `packages/njiani_core/lib/src/profile/profile_controller.dart` | `setDisplayName` writes before it checks state |
| `packages/njiani_core/lib/src/widgets/nj_screen_body.dart` | a `physics` parameter, so pull-to-refresh is not a dead gesture |
| `packages/njiani_core/lib/src/config/app_config.dart` | `SUPPORT_PHONE` |
| `packages/njiani_core/lib/src/l10n/arb/nj_{en,sw}.arb` | 45 strings, both languages |
| `packages/njiani_core/pubspec.yaml` | `image_picker`, `url_launcher` |
| `apps/njiani_{rider,driver}/ios/Runner/Info.plist` | `tel:`, localisations; camera keys on the driver only |
| `apps/njiani_{rider,driver}/android/.../AndroidManifest.xml` | the `ACTION_DIAL` query |
| `supabase/tests/run.sh` | every `*_test.sql`, not a hardcoded list of numbers |
| `tool/dev-db.sh`, `tool/dev-db/supabase-prelude.sql` | the `storage` schema stub; a repeat run explains itself |
| `docs/ARCHITECTURE.md` | D21, D22, and §8 rewritten for the bucket |
| `.env.example`, `docs/CREDENTIALS.md` | `SUPPORT_PHONE`, the bucket, the Xcode step |

### How to test

```sh
# 1. Fill in SUPPORT_PHONE in .env.local (and the Supabase keys, from C3).
# 2. Apply the two new migrations.
supabase db push

# 3. Make yourself an admin, so C16 will work later. Optional for this test:
#    the SQL editor is the service role and can approve without it.
#    insert into public.admins (profile_id)
#      select id from public.profiles where phone = '255XXXXXXXXX';

./tool/check.sh
cd apps/njiani_driver && flutter run --dart-define-from-file=../../.env.local
```

| # | Step | Expected |
| --- | --- | --- |
| 1 | Sign in on the **driver** app | **Drive with Njiani**, not the landing screen |
| 2 | Look at the phone field | Your verified number, `+255 …`, not editable |
| 3 | Type a name, leave the photo | **Submit for review** stays greyed out |
| 4 | Tap the upload box → **Take a photo** | Camera opens. iOS asks for permission, naming the licence |
| 5 | Take the photo | Box turns teal, Submit enables |
| 6 | Turn airplane mode on, tap the box, retake | "Photo didn't upload. Your details are saved." — **and your name and plate are still there** |
| 7 | Airplane mode off, tap the box again | Teal again. One object in the bucket, not two |
| 8 | Submit | Replaced by **We're checking your documents**, showing your plate. No back button |
| 9 | **Force-close the app and reopen** | Straight back to the review screen |
| 10 | Supabase → Storage → licences | **Private**. One folder, named with your user id |
| 11 | In the SQL editor: `select public.review_driver('<your uuid>', 'rejected', 'Glare across the number.');` | **Without touching the phone**, the screen becomes the rejection, with that sentence on it |
| 12 | Read the checklist | Phone **Verified**, vehicle **Accepted**, licence **Rejected** |
| 13 | **Take the photo again** | Back to **We're checking your documents** |
| 14 | In the SQL editor: `select public.review_driver('<your uuid>', 'approved');` | The gate opens by itself — C7's placeholder |
| 15 | `select public.review_driver('<your uuid>', 'rejected');` | **Refused**: `a rejection must say what to fix` |
| 16 | On the rejection screen, tap **Call Njiani** | Your dialler, with `SUPPORT_PHONE` in it |

**Steps 11 and 14 are the ones that matter.** They are the realtime
subscription, and the design's rule that a driver should never have to
reinstall to discover they were approved. Nothing is tapped on the phone.

Step 6 is the second one: it is the only failure path on this screen that
costs a driver anything if it is wrong.

### What I verified, and what I could not

**Verified** — analyze clean, **320 Flutter tests** (300 core, 12 driver, 8
rider), **80 SQL assertions**, 11 signature checks.

**Not verified, and it is the same gap as C4 and C5 —** none of this has run
against real Supabase Storage. Specifically untested:

- that an upload actually lands in the bucket, and that the bucket's size and
  MIME limits reject what they should. The local harness stubs
  `storage.objects` so the **policies** can be tested; it does not run the
  Storage service, so nothing local uploads a byte or signs a URL.
- that `SupabaseDriverRepository.watch()` delivers an approval over a real
  socket. The realtime path is exercised in tests through a fake stream.
- that the iOS camera prompt appears, in either language.

Steps 4–7, 10, 11 and 14 are the first real exercise of all three.

### Known gaps — deliberate

| Gap | Why, and what picks it up |
| --- | --- |
| **A rejection reason is free text, so it ships in whatever language the admin typed** | The column is free text by design — "written by a person and required". Making it bilingual needs a short reason list with codes, and the UI that sets them is the admin web at **C16**. Flagging it rather than guessing at a code list now |
| No approval SMS | The design wants one from the `NJIANI` sender ID. The hook composes bilingually from `profiles.lang` already; sending on an approval needs a database webhook, which is **C13** territory |
| Licence photos are never deleted | Deliberate (D21). The retention schedule is **C17** |
| An admin can only approve from the SQL editor | **C16**, the admin web. `review_driver()` is already the function it will call |
| `dStage` is not here | §13.1, after C7 |

---

### Fix, 2026-10-27 — `db push` replaying migrations that had already run

```
Applying migration 20260922000200_enums.sql...
ERROR: type "vehicle_type" already exists (SQLSTATE 42710)
```

Neither the migration nor the database was broken. Two things have to agree
and only one of them is the schema: the objects, and
`supabase_migrations.schema_migrations`, which is the CLI's own record of
which files it has applied. The objects were all there; the history was empty,
so `db push` started from the top and stopped at the first statement that
cannot run twice.

**This one is mine.** `supabase/README.md` offered the Studio SQL editor as an
equal alternative to `db push` for applying migrations:

> Apply the migrations in filename order, then `seed.sql`, via the SQL editor
> — or with the CLI

Those are not alternatives. Pasting the files in creates every object and
tells the CLI nothing, and the bill arrives at the next push. The README now
says to use `db push`, and says why the other way is not a second option.
`seed.sql` still goes in the editor, because it is reference data rather than
schema and `db push` does not run it.

**What to run.** `supabase/checks/migration-state.sql` — paste it into the SQL
editor or `psql -f` it. It reads only catalogues, writes nothing, and probes
for one object per migration that only that migration creates:

```
 20260922000200_enums            | present | NOT RECORDED | repair: mark applied
 20261026000100_storage_licences | MISSING | NOT RECORDED | will be applied by db push
 RUN THIS                        |         |              | npx supabase migration repair --status applied …
```

The last row is the command, assembled from what is actually there, so it
names the right versions rather than all ten. `migration repair --status
applied` writes the history rows without running the SQL; `db push` then
applies only what is genuinely left.

**What I did not do: make the migrations idempotent.** `create type … if not
exists` would have made the error go away and left the history still wrong,
so the next real migration would land on a database nobody can describe. The
error was doing its job.

The one exception is `20261026000100_storage_licences`, where the three
`create policy` statements became `drop policy if exists` + `create policy`.
Different case: a policy is declarative and the migration restates each one in
full, so dropping and recreating converges on the same end state rather than
hiding a difference — and it is the first of the two C6 files, so it is the
one a half-finished push leaves behind. Both C6 migrations now apply twice in
a row with no error; verified by running each of them twice.

The script has a fourth verdict, **RECORDED BUT MISSING**, for the opposite
problem: the CLI thinks a file ran and the objects are not there. That is real
drift, and marking it applied would bury it, so it says so instead of
offering to repair. All four verdicts were exercised against a local database
put into each state deliberately.

| File | Change |
| --- | --- |
| `supabase/checks/migration-state.sql` | **new** — the diagnostic and the repair command |
| `supabase/migrations/20261026000100_storage_licences.sql` | policies drop-then-create, so a half-finished push can be re-run |
| `supabase/README.md` | `db push` is the way, not one of two ways; a troubleshooting section for this error |
| `docs/CREDENTIALS.md` | points at it from the C6 checklist, where the push happens |

---

## C7 — Pick a direction, and go online · 🧪 awaiting your test

One screen, `dDirection`, and the five SQL functions behind it. This is the
screen the design calls "the one that makes Njiani not a ride-hailing app":
the driver declares where they are going **before** seeing a single request,
and the feed at C9 is derived from that declaration rather than from a radius
around them.

### Credentials

**None.** Two pieces of platform configuration, both committed and both
guarded by a test: `NSLocationWhenInUseUsageDescription` (and its Kiswahili
twin) on iOS, `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` on Android,
driver app only.

**When-in-use, on both, deliberately.** No `ACCESS_BACKGROUND_LOCATION`, no
`NSLocationAlways…`. Njiani has no reason to know where a driver is with the
app closed; asking would mean a Play Console declaration and an App Review
conversation for a promise the product does not need to make. The tests assert
those keys are *absent* as well as asserting the others are present.

### Choosing a destination chooses the direction

The thing I most expected to need a compass for turned out not to.

Ubungo→Kimara and Kimara→Ubungo are two route rows over the same tarmac, so a
driver's point sits inside both corridors. But any given stage is ahead on
exactly one of them. `destinations_ahead(point)` returns both routes' stages
with their distance along the road, and picking one settles the heading:

```
 direction_label |        name         |  m
-----------------+---------------------+------
 Eastbound       | Ubungo Bus Terminal |  807
 Westbound       | Shekilango          |  883
 Westbound       | Ubungo Maji         | 1765
 …
 Westbound       | Kimara Mwisho       | 8006
```

One question, and the one a driver already knows the answer to. The screen
heads each group with where that road *ends* — "Towards Kimara Mwisho" —
because nobody standing at a stage thinks in compass points.

Two details in that query that are not decoration. The stage the driver is
standing at is excluded (`p_min_ahead_m`, 400m, comfortably under the ~800m
gap between stages here) — it is not a destination, and the slack also
forgives a fix that landed just past it. And the ordering is by `seq`, in the
direction of travel, asserted in SQL: a list that puts Kimara Mwisho above
Shekilango is a list nobody can read at a stage.

### A hole in the schema, found while writing the function

`driver_sessions` had a CHECK tying `seats_total` to `vehicle_type`, and
**nothing tying either of them to the driver's own record**. A boda rider
could have opened a bajaj session with three seats and been offered
three-seat work. The RLS policy `sessions_own` is `for all`, so a hand-rolled
insert was all it took.

`go_online()` closes it by not asking the client. It reads `vehicle_type` and
the seat count from `drivers`, and `insert`/`update` are now revoked from
`authenticated` on that table except for `last_pos` and `last_pos_at` — the
one thing a client legitimately writes:

```
✓ a driver cannot insert a session by hand                  42501
✓ a driver cannot hand themselves more free seats           42501
✓ a driver CAN report their position                        (allowed)
✓ a boda session has one seat, whatever the client would like
```

It also enforces the C6 approval gate. The router already holds an unapproved
driver at the C6 screens, but a gate in the UI is not a gate:

```
✓ an unapproved driver cannot go online                     42501
✓ someone with no application cannot go online              P0002
```

### Changing direction without selling a seat twice

The design says: *"Changing direction ends the session and starts a new one.
Claimed seats survive."* Both halves matter, and the second one has a trap in
it. If the new session opened with a full vehicle, a driver carrying two
passengers would be offered three more seats.

So `go_online` counts the seats still held — `claimed` or `aboard` — and opens
with `seats_total` minus those:

```
✓ the claimed seat survives the change
✓ the new session offers only the seats that are genuinely free   2/3
```

`go_offline()` ends the session and touches nothing else. A claimed seat is a
passenger who is waiting or already in the vehicle, and closing an app is not
a cancellation — the driver still owes them the trip. Cancelling is
`release_trip_seat`, a separate deliberate act.

### No GPS is a state, not an error

A driver between buildings at Ubungo may never get a fix. The screen asks,
waits 8 seconds, and then offers the stage list — and every message names the
way round as well as the problem:

| What happened | What it says |
| --- | --- |
| Denied | "Njiani needs your location to know which passengers are ahead of you. You can choose your stage instead." + **Try again** |
| Denied forever | "Location is blocked for Njiani. Turn it on in Settings, or choose your stage below." — **no Try again**, because only Settings can undo it and the button would be a lie |
| Switched off | "Location is switched off on this phone." |
| Timed out | "Couldn't find you — too many buildings, maybe." |

Picking a stage by hand runs the same query from that stage's coordinates,
resolved on the server. `go_online` then takes the stage id instead of a
point: a session with no position is treated as being at the *start* of the
route, which for a driver already halfway along it is a feed full of
passengers behind them.

### Four bugs, and where each came from

**The layout one, from the first test run.** `_DestinationTile` sized itself
from a `LayoutBuilder` so two would fit per row. `NjScreenBody` wraps its
column in an `IntrinsicHeight`, which asks children for a dry layout, and a
`LayoutBuilder` cannot give one: `_RenderLayoutBuilder does not support dry
layout`, the instant the screen was pumped. It is rows of two `Expanded`
tiles now, which needs no such question asked.

**The stage sheet could not be tapped.** The list was a `shrinkWrap` ListView
inside a `MainAxisSize.min` column, so with ten stages it sized itself past
the bottom of the sheet — and entries past the edge are not merely hidden,
they receive no taps. Bounded to half the screen height and scrolling inside
that. The test scrolls to the stage before tapping, which is also what a
driver does.

**No tap feedback in that sheet.** `NjSheet`'s background is a plain decorated
box, so a `ListTile` inside it painted its ink splash behind that box.
Flutter says so out loud — *"ListTile background color or ink splashes may be
invisible"* — but only once a test pumped it. Its own transparent `Material`
now.

**English chrome around a Kiswahili place name.** The screen read
`languageProvider` to pick which name to show, while the strings came from
`Localizations`. Those answer different questions — the provider is the
*first router gate*, "has a language been confirmed" — and in a test that set
one without the other they disagreed. There is an `NjLocale.of(context)` now
(D25), reading the same locale the strings came from, and the shared test
harness loads the provider so the two cannot drift apart again. **This is the
second time that harness gap has bitten**; at C5 it made a test assert against
the wrong language. Fixed at the source this time, in both places.

### Also: one enum fewer

`NjVehicleType` was a C1 design-system enum carrying seats and a label in each
language. `VehicleType` arrived at C6 with the database's own codes and the
same seat counts. Nothing outside its own test ever used the C1 one, and two
enums owning "a bajaj has three seats" is one more than can stay true. Its
test coverage moved to `driver_test.dart` with the fact.

The same fact in SQL is `seats_for(vehicle_type)` now, and a test asserts it
agrees with the `seats_match_vehicle` CHECK — if those two ever disagree,
every `go_online` is refused by the constraint and nobody can work.

### Files added

| File | What it is |
| --- | --- |
| `supabase/migrations/20261027000100_going_online.sql` | `seats_for`, `nearest_stage`, `destinations_ahead`, `destinations_from_stage`, `go_online`, `go_offline`, `report_position`, and the session grants |
| `supabase/tests/06_going_online_test.sql` | 30 assertions |
| `packages/njiani_core/lib/src/places/place.dart` | `NjRoute`, `Stage`, `Destination`, `LatLng` |
| `packages/njiani_core/lib/src/places/places_repository.dart` | the stage list, what is ahead, and `wktPoint` |
| `packages/njiani_core/lib/src/driver/driver_session.dart` | `DriverSession` |
| `packages/njiani_core/lib/src/driver/session_repository.dart` | the C7 functions, and a fake |
| `packages/njiani_core/lib/src/driver/session_controller.dart` | the session, and `directionOptionsProvider` |
| `packages/njiani_core/lib/src/driver/driver_location.dart` | `geolocator` behind an interface, plus a fake |
| `packages/njiani_core/lib/src/screens/driver_direction_screen.dart` | `dDirection` |
| `packages/njiani_core/test/direction_test.dart` | 25 tests |

### Files changed

| File | Change |
| --- | --- |
| `packages/njiani_core/lib/src/app/nj_router.dart` | the fourth gate: approved, but no heading declared |
| `packages/njiani_core/lib/src/locale/nj_locale.dart` | `NjLocale.of(context)` (D25) |
| `packages/njiani_core/lib/src/widgets/nj_seat_indicator.dart` | `NjVehicleType` retired |
| `packages/njiani_core/lib/src/driver/driver_repository.dart` | `DriverFailure.notApproved`, and one `driverFailureMessage` instead of a copy per screen |
| `packages/njiani_core/test/support/harness.dart` | loads `languageProvider`, so it cannot disagree with `MaterialApp` |
| `apps/njiani_driver/ios`, `android` | the location keys, both languages |
| `apps/njiani_{driver,rider}/test/platform_config_test.dart` | location present / background absent; matched on the XML element so a comment cannot fail the assertion |
| `docs/ARCHITECTURE.md` | D23, D24, D25; §8 rewritten for the session grants |

### How to test

```sh
supabase db push          # one new migration
./tool/check.sh
cd apps/njiani_driver && flutter run --dart-define-from-file=../../.env.local
```

| # | Step | Expected |
| --- | --- | --- |
| 1 | Open the driver app, already approved | **Where are you heading?** — not the feed |
| 2 | Allow location when asked | The prompt names the licence… no: it names *passengers ahead of you*. Then your nearest stage under **Starting from your location** |
| 3 | Read the destination list | Two groups, headed **Towards Kimara Mwisho** and **Towards Ubungo Bus Terminal**. The stage you are standing at is not in either |
| 4 | Check the order inside a group | Nearest first, in road order — not alphabetical |
| 5 | Tap a destination | Turns bajaj-yellow; the button becomes **Go online · heading to <that stage>** |
| 6 | Tap it | The screen is replaced by the C9 placeholder |
| 7 | Come back to this screen | A yellow **You're online** banner, and the button now says **Change · heading to …** |
| 8 | Pick a different destination and tap Change | Still exactly one session. In Supabase → `driver_sessions`, the old row is `offline` with an `ended_at`, not deleted |
| 9 | Tap **Go offline**, then reopen the app | Straight back to this screen — no session, so nothing to show in a feed |
| 10 | Deny location, or turn it off, and reopen | A sentence saying **why** it was asking, plus **Choose where you are** |
| 11 | Tap that and pick your stage | The same destination list, headed **Starting from** |
| 12 | Go online from there, then check `driver_sessions` | `last_pos` is set — from the stage you named, not null |
| 13 | Switch the phone to Kiswahili and reopen | **Unaelekea wapi?**, and the stage names in Kiswahili too |

**Steps 3 and 4 are the product.** If the list ever shows a stage behind you,
or sorts alphabetically, the thing that makes Njiani different is broken.

**Step 12 matters more than it looks.** A session with no position is treated
as being at the start of the route, so a driver at Kimara Suka would get a
feed full of passengers back at Ubungo.

### What I verified, and what I could not

**Verified** — analyze clean, **347 Flutter tests** (324 core, 14 driver, 9
rider), **110 SQL assertions**, 11 signature checks.

**Not verified** — the same gap as C4, C5 and C6, plus one new one:

- No part of this has run against real Supabase. `go_online` and the
  destination query are exercised against a local Postgres that mirrors the
  hosted schema, but `SupabaseSessionRepository` and
  `SupabasePlacesRepository` have never spoken to PostgREST. In particular
  **the `geography` parameters are passed as WKT strings** (`POINT(lng lat)`),
  which Postgres casts correctly — I checked — but which PostgREST has to
  hand over unmangled first. Steps 2, 11 and 12 are the first test of that.
- The GPS path is a fake in every test. Step 2 is the first real fix.
- `wktPoint` puts longitude first. There is a test pinning it, because
  swapping them puts a driver in Dar es Salaam off the coast of Somalia —
  close enough to look plausible, far enough that nothing ever matches.

### Known gaps — deliberate

| Gap | Why, and what picks it up |
| --- | --- |
| **No continuous position tracking** | `report_position` exists and is tested; nothing calls it on a timer yet. Throttling it properly is a battery and data decision that belongs with the feed, where a stale position actually costs something — **C9** |
| `dStage`, "I'm parked · show me where demand is" | The design puts it at **§13.1**, not C7. `demand_near()` already exists from C3, so it is a screen rather than a feature |
| The route board and seat bar in the roadmap line | Those are the feed's chrome at **C9 / C10**, not this screen's. The session carries the seat counts they will read |
| A driver with every seat taken cannot change direction | `go_online` refuses with "every seat is already taken". Correct for now — there is nowhere to put anyone — but it also blocks a legitimate re-heading. Revisit at **C11**, when dropping a passenger exists |
