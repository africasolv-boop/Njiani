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
| — | Planning & architecture | 🧪 awaiting your review | |
| C0 | Monorepo scaffold + both app shells | 🔜 | |
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

## Planning & Architecture · 🧪 awaiting your review

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

**Sign-off** — _pending_

---

## C0 — Monorepo scaffold + both app shells · 🔜

_Not started. Begins on your approval of the plan above._

**Goal** — both apps build and run on your iPhone and your Android device, sharing one package.

**Planned files**

```
pubspec.yaml                          pub workspace root
melos.yaml or tool/                   task running (if needed)
analysis_options.yaml                 lint rules, shared
.gitignore                            all credential patterns (CREDENTIALS.md §"Never committed")
.env.example                          every key, blank
CLAUDE.md                             repo conventions for future sessions
packages/njiani_core/                 shared package skeleton
apps/njiani_rider/                    "Njiani"
apps/njiani_driver/                   "Njiani Driver"
```

**Credentials needed** — none. C0 runs with an empty `.env.local`.

**Sign-off** — _not started_
