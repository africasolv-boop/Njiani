# Njiani — Credentials Index

> **Every value here is intentionally blank.** I never fill these in, and none of them are ever
> committed. You add them locally when you test.
>
> **Rule:** real values go in `.env.local` (git-ignored). `.env.example` in the repo root holds
> the same keys with empty values and is committed as the template.

**Status key:** ⬜ not needed yet · 🟡 needed for the component listed · ✅ you have added it

---

## How to add a credential

```bash
cp .env.example .env.local     # once
# edit .env.local, fill in only the keys the current component needs
```

The app reads them via `--dart-define-from-file`:

```bash
flutter run --dart-define-from-file=../../.env.local
```

`BUILD_LOG.md` repeats the exact run command for each component.

---

## 1. Supabase — needed at C3

| Key | Where to get it | Status |
| --- | --- | --- |
| `SUPABASE_URL` | Supabase dashboard → Project Settings → API → Project URL | 🟡 **needed now** |
| `SUPABASE_ANON_KEY` | same page → Project API keys → `anon` `public` | 🟡 **needed now** |
| `SUPABASE_SERVICE_ROLE_KEY` | same page → `service_role` | 🟡 **needed now** |

**Before applying the migrations**, enable two extensions in the dashboard
(Database → Extensions): **postgis** and **pg_cron**. The schema will not
apply without them.

Supabase puts them in the `extensions` schema, which is not on the default
search_path — the migrations handle that themselves, and `supabase/README.md`
explains why it matters.

`supabase/README.md` has the full apply-and-test procedure, including a
no-Docker path for Windows.

⚠️ **`SUPABASE_SERVICE_ROLE_KEY` bypasses all Row Level Security.** It goes in Edge Function
secrets and your local `.env.local` only. It must **never** appear in `apps/` code, because
anything in the app binary can be extracted from the app binary.

**Local alternative:** `supabase start` prints a local URL and anon key. Use those for local
work and you need no hosted project until you want to test across two real phones.

---

## 2. SMS gateway — Beem Africa — needed at C4

All four are **Supabase Edge Function secrets**, not app config. They are never
compiled into the app.

```sh
supabase secrets set \
  SMS_PROVIDER=console \
  SEND_SMS_HOOK_SECRET='v1,whsec_...' \
  BEEM_API_KEY='' \
  BEEM_SECRET_KEY='' \
  BEEM_SENDER_ID=NJIANI
```

| Key | Where to get it | Status |
| --- | --- | --- |
| `SMS_PROVIDER` | `console` or `beem`. Defaults to `console` | ✅ no credential needed |
| `SEND_SMS_HOOK_SECRET` | Dashboard → Authentication → Hooks → Send SMS hook. Shown as `v1,whsec_…` | 🟡 **needed to deploy the hook** |
| `BEEM_API_KEY` | Beem dashboard → API credentials | 🟡 needed for real SMS |
| `BEEM_SECRET_KEY` | same | 🟡 needed for real SMS |
| `BEEM_SENDER_ID` | Your approved sender, `NJIANI` | ⏳ needs Beem approval |

**`SEND_SMS_HOOK_SECRET` is not optional.** The hook is deployed with
`--no-verify-jwt`, because Supabase calls it before any user exists and there
is no JWT to check. The Standard Webhooks signature is what authenticates the
request instead, and the function refuses to send without it — otherwise anyone
who learned the URL could spend Njiani's SMS credit.

**You can build and test all of C4 with no SMS credential at all.** With
`SMS_PROVIDER=console` the code is written to the function log:

```sh
supabase functions logs send-sms-hook
```

⏳ **The `NJIANI` sender ID still gates real sending.** Beem rejects an
unregistered `source_addr`, so `SMS_PROVIDER=beem` cannot work until it is
approved. Nothing else in the build depends on it.

### Supabase dashboard settings C4 needs

- [ ] **Authentication → Providers → Phone**: enabled.
      ⚠ The form demands an SMS provider with no "none" option, even though
      the hook means it is never called. `supabase/README.md` has the two ways
      through it.
- [ ] **SMS OTP Expiry**: raise from 60s to **300s**. At 60s a code expires at
      the same moment the app offers a resend, so anyone who leaves the app to
      read the SMS is racing it
- [ ] **Authentication → Hooks → Send SMS hook**: pointed at the deployed
      function, with the signing secret pasted
- [ ] **Authentication → Rate limits**: set deliberately. Every send costs
      money, and this is the only cap that cannot be bypassed by reinstalling
      the app
- [ ] **SMS OTP length**: leave at **6**. Supabase will not go below it — see
      the note in `docs/BUILD_LOG.md` under C4

## 3. Driver verification — needed at C6

| Key | Where to get it | Status |
| --- | --- | --- |
| `SUPPORT_PHONE` | **You decide it.** The number behind every "Call Njiani" button | 🟡 **needed now** |

Full international form, so the dialler works from any SIM:
`SUPPORT_PHONE=+255XXXXXXXXX`. Not a secret — it goes on the vehicle stickers —
but a build with the wrong one strands exactly the people who are already
stuck. **Left blank, the button is hidden rather than dialling nothing.**

### No credential, but C6 does not work without it

- [ ] **Storage → the `licences` bucket** is created by
      `20261026000100_storage_licences.sql`. Nothing to click: run
      `supabase db push`. Check afterwards that Storage → licences shows
      **Private**. A public bucket would mean every driver's licence photo is
      readable by anyone who guesses a URL.

      If that push stops with `type "vehicle_type" already exists`, the
      database is fine and the CLI's history is behind — see
      *`db push` wants to re-apply migrations that already ran* in
      `supabase/README.md`, and run `supabase/checks/migration-state.sql`
      for the exact repair command.
- [ ] **An `admins` row for yourself**, or nothing can be approved.
      `review_driver()` refuses a signed-in caller without one:
      ```sql
      insert into public.admins (profile_id)
      select id from public.profiles where phone = '255XXXXXXXXX';
      ```
      Approving from the SQL editor works without this — that connection is
      the service role — but the admin web at C16 will need it.

### iOS: the camera prompt, and the one Xcode step

`apps/njiani_driver/ios/Runner/Info.plist` carries
`NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`. **These are
not optional** — iOS terminates the app the instant the camera opens without
them, which looks like a crash in the sign-up screen rather than a missing
key. They are already committed.

The Kiswahili versions are in
`apps/njiani_driver/ios/Runner/sw.lproj/InfoPlist.strings`, with the English
alongside in `en.lproj/`. **A `.lproj` folder only ships if it is a member of
the `Runner` target**, which is a checkbox in Xcode rather than something a
file on disk can do by itself:

- [ ] Xcode → open `apps/njiani_driver/ios/Runner.xcworkspace` → drag
      `en.lproj` and `sw.lproj` into the `Runner` group → tick **Runner** under
      *Add to targets*.

Until that is done the prompt appears in English for everyone. It is the one
user-facing string in the project that is not covered by the both-languages
rule from the Dart side, because iOS reads it from the bundle and not from our
`.arb` files. Nothing crashes either way.

### Android

No permission is declared for the camera, and none is needed: `image_picker`
uses the system camera app. Both manifests do declare a `<queries>` entry for
`ACTION_DIAL`, without which Android 11+ reports that a dialler which is
plainly installed cannot be opened. Already committed; the
`platform_config_test.dart` in each app fails if either goes missing.

---

## 4. Direction picker — needed at C7

No credential. Two pieces of platform configuration, both already committed,
both guarded by `platform_config_test.dart`:

- **iOS** — `NSLocationWhenInUseUsageDescription` in the driver app's
  `Info.plist`, with the Kiswahili version in `sw.lproj`. **The same Xcode
  step as C6 applies**: the `.lproj` folders must be members of the `Runner`
  target or the prompt ships in English only.
- **Android** — `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` in the
  driver app's manifest.

**When-in-use only, on both.** There is no `ACCESS_BACKGROUND_LOCATION` and no
`NSLocationAlways…`, deliberately: Njiani has no reason to know where a driver
is with the app closed. Adding either means a Play Console declaration and an
App Review conversation, for a promise the product does not need to make. The
tests assert their absence as well as the others' presence.

The rider app asks for no location at all yet. A passenger picks a stage from
a list at C8; location arrives at C14 with the map, and asking before anything
uses it is a permission prompt with no answer to "why?".

---

## 5. Firebase Cloud Messaging — needed at C13

Only FCM is used. No Firestore, no Firebase Auth, no Firebase hosting.

| File / key | Where to get it | Status |
| --- | --- | --- |
| `apps/njiani_rider/android/app/google-services.json` | Firebase console → Project settings → Your apps → Android | ⬜ C13 |
| `apps/njiani_driver/android/app/google-services.json` | same, **separate Android app entry** | ⬜ C13 |
| `apps/njiani_rider/ios/Runner/GoogleService-Info.plist` | same → iOS app | ⬜ C13 |
| `apps/njiani_driver/ios/Runner/GoogleService-Info.plist` | same, separate iOS app entry | ⬜ C13 |
| `FCM_SERVICE_ACCOUNT_JSON` | Project settings → Service accounts → Generate new private key | ⬜ C13 |

Two apps (D4) means **four** Firebase app registrations under one Firebase project — one
Android + one iOS per app, each with its own bundle/package ID.

`FCM_SERVICE_ACCOUNT_JSON` is a server credential; it goes in Supabase Edge Function secrets,
never in the app.

All four config files are git-ignored.

---

## 6. Maps and routing — needed at C14

Nothing is required before C14. `flutter_map` runs on free tiles during development.

| Key | Where to get it | Status |
| --- | --- | --- |
| `MAP_TILE_URL` | Your Cloudflare R2 / Supabase Storage `.pmtiles` URL (self-hosted, D7) | ⬜ C14 |
| `MAP_TILE_KEY` | Only if you use a hosted provider (MapTiler/Stadia) instead of self-hosting | ⬜ C14 |
| `OSRM_BASE_URL` | Your own OSRM instance (D8). The public demo server forbids production use | ⬜ C14 |

**Self-hosting path (D7/D8), so you own it and pay nothing recurring for tiles:**
1. Tanzania extract from [download.geofabrik.de](https://download.geofabrik.de/africa/tanzania.html)
2. Planetiler → `tanzania.pmtiles`, upload to Cloudflare R2 (free egress)
3. OSRM container on a small VPS with the same extract, for directions and ETA

---

## 7. Error tracking — needed at C17

| Key | Where to get it | Status |
| --- | --- | --- |
| `SENTRY_DSN` | sentry.io → Project → Settings → Client Keys (DSN) | ⬜ C17 |

Leave blank and Sentry stays disabled — the app runs normally without it.

---

## 8. Android release signing — needed at C18

| File / key | Where to get it | Status |
| --- | --- | --- |
| `android/upload-keystore.jks` (per app) | You generate it with `keytool`. **Back it up.** Lose it and you cannot update the app on Play ever again | ⬜ C18 |
| `android/key.properties` (per app) | You write it: `storePassword`, `keyPassword`, `keyAlias`, `storeFile` | ⬜ C18 |
| `PLAY_SERVICE_ACCOUNT_JSON` | Google Play Console → Setup → API access | ⬜ C18 |

Both keystore and `key.properties` are git-ignored. C18 documents the `keytool` command.

---

## 9. iOS release — needed at C18

| Item | Where to get it | Status |
| --- | --- | --- |
| Apple Developer Program membership | developer.apple.com — $99/year | ⬜ C18 |
| `APPLE_TEAM_ID` | developer.apple.com → Membership | ⬜ C18 |
| Bundle IDs | You choose, e.g. `tz.njiani.rider`, `tz.njiani.driver` | ⬜ C18 |
| APNs auth key `.p8` | Certificates, IDs & Profiles → Keys → new key with APNs enabled | ⬜ C13 (push on iOS) |
| App Store Connect API key | App Store Connect → Users and Access → Integrations | ⬜ C18 |

⚠️ **iOS push needs the APNs `.p8` uploaded to Firebase** (Project settings → Cloud Messaging →
APNs Authentication Key). Without it, FCM cannot deliver to iPhones. This is the one C13 item
that needs the paid Apple account early.

---

## 10. Optional

| Key | Purpose | Status |
| --- | --- | --- |
| `POSTHOG_API_KEY` | Product analytics, if you want funnels beyond the metrics in §10 of ARCHITECTURE | ⬜ |

---

## Never committed

`.gitignore` blocks all of these:

```
.env
.env.local
.env.dev
.env.prod
**/google-services.json
**/GoogleService-Info.plist
**/key.properties
**/*.jks
**/*.keystore
**/*.p8
**/*.p12
**/*.mobileprovision
```

If you ever suspect a key reached a commit: **rotate it first**, then clean history. Rotation is
the fix; history rewriting is only cleanup.
