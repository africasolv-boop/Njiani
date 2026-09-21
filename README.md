# Njiani

Njiani connects passengers with bajaj and boda boda drivers who are already
heading in the same direction, with the price agreed before pickup.

Launching on one corridor in Dar es Salaam: **Ubungo → Kimara, Morogoro Road.**

---

## Documentation

| Document | What it holds |
| --- | --- |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | **The master document.** Every decision, the data model, the matching logic, the roadmap |
| [`docs/BUILD_LOG.md`](docs/BUILD_LOG.md) | What has been built, every file changed, and how to test each component |
| [`docs/CREDENTIALS.md`](docs/CREDENTIALS.md) | Every credential — blank — with where to get it and when it is needed |

## Layout

```
apps/njiani_rider/     "Njiani"         — passenger app   (tz.njiani.rider)
apps/njiani_driver/    "Njiani Driver"  — driver app      (tz.njiani.driver)
packages/njiani_core/  shared design system, models, data layer
supabase/              migrations, edge functions, seed data   (from C3)
docs/                  architecture, build log, credentials
```

Two store apps, one codebase. A fix in `njiani_core` ships to both.

## Getting started

Requires **Flutter 3.27+** (developed on 3.47.5 / Dart 3.13.4).

```sh
flutter pub get                 # run once, at the repo root — resolves all three packages
cp .env.example .env.local      # blank template; fill in as components need it

cd apps/njiani_rider  && flutter run --dart-define-from-file=../../.env.local
cd apps/njiani_driver && flutter run --dart-define-from-file=../../.env.local
```

No credentials are required to run the current build.

## Checks

```sh
flutter analyze                 # whole workspace
flutter test                    # whole workspace
```
