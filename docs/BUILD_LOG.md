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
| C1 | Design system (rev. 2, from the design project) | 🧪 awaiting your test | |
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

## C1 rev. 2 — Design system from the design project · 🧪 awaiting your test

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

_Awaiting your test._
