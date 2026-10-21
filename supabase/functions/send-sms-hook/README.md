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
