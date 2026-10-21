# send-sms-hook

Delivers Njiani's login codes. Supabase Auth generates and verifies them; this
only carries the message to a phone.

## Deploy

```sh
supabase secrets set \
  SMS_PROVIDER=console \
  SEND_SMS_HOOK_SECRET='v1,whsec_...' \
  BEEM_API_KEY='' \
  BEEM_SECRET_KEY='' \
  BEEM_SENDER_ID=NJIANI

supabase functions deploy send-sms-hook --no-verify-jwt
```

`--no-verify-jwt` is required. The hook is called before any user exists, so
there is no JWT; the request is authenticated by its Standard Webhooks
signature, which the function checks and refuses without.

Then: Dashboard → Authentication → Hooks → **Send SMS hook** → point it at the
deployed URL and paste the same signing secret.

## Is it even deployed?

```sh
curl https://<project-ref>.supabase.co/functions/v1/send-sms-hook
```

```json
{"ok":true,"provider":"console",
 "configured":{"SEND_SMS_HOOK_SECRET":true,"BEEM_API_KEY":false,...}}
```

Presence only, never values. **If this does not answer, the function is not
deployed** — and Supabase reports an unreachable hook to the app as
`Gateway Timeout`, an error that says nothing about its own cause. Check here
first, before anything in the app.

## Two modes

| `SMS_PROVIDER` | Behaviour |
| --- | --- |
| `console` (default) | Logs the code, sends nothing, costs nothing |
| `beem` | Sends through Beem Africa |

`console` is the default deliberately: a half-finished configuration should
not quietly start spending money. Read a logged code with
`supabase functions logs send-sms-hook`.

## Before switching to `beem`

- [ ] The `NJIANI` sender ID is registered and approved — Beem rejects an
      unregistered `source_addr`, so this cannot be skipped
- [ ] There is credit on the account
- [ ] `Authentication → Providers → Phone` is enabled
- [ ] `Authentication → Rate limits` is set deliberately. Every send costs
      money, and this is the only place a cap cannot be bypassed by
      reinstalling the app

## No imports, on purpose

Everything in here is a Web standard available in Deno. An earlier version
imported `node:crypto` and used a bare `Buffer`, which is not a global in Deno
— the module failed to boot, so the hook never answered, and that surfaced as
`Gateway Timeout`. Keeping the function dependency-free removes that class of
failure and keeps cold starts inside the hook's short timeout.

`signature.ts` is pure Web Crypto for the same reason, which also lets it be
tested outside Deno: `node tool/check-sms-signature.mjs` checks it against an
independently computed HMAC.

## The API this calls

Confirmed against Beem's own client library, not from documentation:

```
POST https://apisms.beem.africa/v1/send
Authorization: Basic base64(api_key:secret_key)

{ "source_addr": "NJIANI", "schedule_time": "", "encoding": 0,
  "message": "...", "recipients": [{"recipient_id": 1,
  "dest_addr": "255712345678"}] }
```

`dest_addr` takes no `+`.
