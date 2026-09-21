# Njiani — working conventions

Read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) first. It is the master
document and every decision is justified there.

## How this project is built

One component at a time. Each component is built, documented in
[`docs/BUILD_LOG.md`](docs/BUILD_LOG.md) with its complete file list and local
test steps, then tested on a real iPhone and a real Android device before the
next one starts. Do not start the next component without sign-off.

## Layout

```
apps/njiani_rider/     "Njiani"         passenger app   tz.njiani.rider
apps/njiani_driver/    "Njiani Driver"  driver app      tz.njiani.driver
packages/njiani_core/  everything shared by both apps
supabase/              migrations, edge functions, seed      (from C3)
tool/check.sh          analyze + test the whole workspace
```

This is a **Dart pub workspace**. Run `flutter pub get` at the root only; there
is one lockfile, at the root. Member packages must not have their own.

## Rules

**Shared code goes in `njiani_core`.** If something is not specific to one app,
it belongs there. Duplicating a widget or a model between the two apps defeats
the reason the monorepo exists.

**Never commit a credential.** Every key lives blank in `.env.example` and is
documented in [`docs/CREDENTIALS.md`](docs/CREDENTIALS.md). Real values go in
`.env.local`, which is git-ignored. If a secret ever reaches a commit, rotate it
first, then clean history.

**The service role key never appears in `apps/`.** It bypasses all row level
security, and anything compiled into an app binary can be extracted from that
binary. It belongs in Edge Function secrets only.

**Run `./tool/check.sh` before every commit.** Analysis must be clean and all
tests must pass.

**Generated files are not committed.** `*.g.dart` and `*.freezed.dart` are
git-ignored; regenerate with
`dart run build_runner build --delete-conflicting-outputs` (from C3, when code
generation is introduced).

**Migrations are the only source of schema truth.** Never change the database by
clicking in Supabase Studio — write a migration.

**Both languages, always.** Every user-facing string ships in English and
Kiswahili. No English-only strings, from C2 onward.

## Commands

```sh
flutter pub get                  # at the root, resolves all three packages
./tool/check.sh                  # analyze + test everything

cd apps/njiani_rider  && flutter run --dart-define-from-file=../../.env.local
cd apps/njiani_driver && flutter run --dart-define-from-file=../../.env.local
```
