// Supabase "Send SMS" auth hook — delivers Njiani's login codes through Beem.
//
// WHAT THIS DOES AND DOES NOT DO
//
// Supabase Auth generates the code, decides whether a submitted code is
// correct, caps the attempts and issues the session. This function only
// *delivers* the message. Beem never learns whether a code was accepted, and
// nothing here can authenticate anybody.
//
// NO IMPORTS, ON PURPOSE
//
// Everything used here is a Web standard available in Deno. An earlier version
// imported `node:crypto` and used a bare `Buffer`, which is not a global in
// Deno. A module that fails to boot never answers, and Supabase reports that
// to the app as "Gateway Timeout" — an error that says nothing about its own
// cause. Keeping this file dependency-free removes that whole class of
// failure, and makes cold starts fast enough for the hook's short timeout.
//
// WIRING IT UP (Dashboard → Authentication → Hooks → Send SMS hook)
//
//   1. supabase secrets set SMS_PROVIDER=console \
//        SEND_SMS_HOOK_SECRET='v1,whsec_...' \
//        BEEM_API_KEY='' BEEM_SECRET_KEY='' BEEM_SENDER_ID=NJIANI
//   2. supabase functions deploy send-sms-hook --no-verify-jwt
//   3. Point the hook at the deployed URL and paste the same signing secret.
//
// `--no-verify-jwt` is required: Auth calls this before any user exists, so
// there is no JWT to verify. The Standard Webhooks signature authenticates the
// request instead, and this function refuses to send without it.
//
// HEALTH CHECK
//
//   curl https://<project>.supabase.co/functions/v1/send-sms-hook
//
// Returns which provider is configured and which secrets are present (never
// their values). If that does not answer, the function is not deployed and no
// amount of looking at the app will reveal it.

import { isSignatureValid } from './signature.ts';

const BEEM_SEND_URL = 'https://apisms.beem.africa/v1/send';

/// Supabase gives an auth hook only a few seconds. Beem is given less than
/// that, so a slow gateway returns a real error instead of being cut off as a
/// timeout with no explanation.
const BEEM_TIMEOUT_MS = 4000;

interface SendSmsHookPayload {
  user?: { id?: string; phone?: string };
  sms?: { otp?: string };
}

/// Beem wants a bare international number: `255712345678`, no plus.
function toBeemAddress(e164: string): string {
  return e164.replace(/\D/g, '');
}

/// The message body.
///
/// Short on purpose: one SMS segment is 160 GSM-7 characters and anything
/// longer is billed as two. The sender ID already says NJIANI, so the text
/// does not repeat it.
function messageFor(otp: string): string {
  return `${otp} ni namba yako ya Njiani. Usimpe mtu mwingine.\n` +
    `${otp} is your Njiani code. Do not share it.`;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/// Tells Supabase the send failed, in the shape its auth hooks expect.
function hookError(message: string, status = 500): Response {
  return json({ error: { http_code: status, message } }, status);
}

Deno.serve(async (request: Request) => {
  const provider = Deno.env.get('SMS_PROVIDER') ?? 'console';

  // ---- health check -------------------------------------------------------
  // Deliberately reports presence, never values.
  if (request.method === 'GET') {
    return json({
      ok: true,
      function: 'send-sms-hook',
      provider,
      configured: {
        SEND_SMS_HOOK_SECRET: Boolean(Deno.env.get('SEND_SMS_HOOK_SECRET')),
        BEEM_API_KEY: Boolean(Deno.env.get('BEEM_API_KEY')),
        BEEM_SECRET_KEY: Boolean(Deno.env.get('BEEM_SECRET_KEY')),
        BEEM_SENDER_ID: Deno.env.get('BEEM_SENDER_ID') ?? null,
      },
    }, 200);
  }

  if (request.method !== 'POST') {
    return hookError('Method not allowed.', 405);
  }

  // Logged first, so the logs show whether the function was reached at all.
  console.log(`[njiani] hook invoked, provider=${provider}`);

  const body = await request.text();

  // ---- authenticate the caller -------------------------------------------
  const hookSecret = Deno.env.get('SEND_SMS_HOOK_SECRET');
  if (!hookSecret) {
    console.error('SEND_SMS_HOOK_SECRET is not set; refusing to send.');
    return hookError('Hook is not configured: SEND_SMS_HOOK_SECRET is missing.');
  }

  const id = request.headers.get('webhook-id') ?? '';
  const timestamp = request.headers.get('webhook-timestamp') ?? '';
  const signature = request.headers.get('webhook-signature') ?? '';

  if (!await isSignatureValid(hookSecret, id, timestamp, body, signature)) {
    console.error('Rejected a request with a bad webhook signature.');
    return hookError('Unauthorized.', 401);
  }

  // ---- read the payload ---------------------------------------------------
  let payload: SendSmsHookPayload;
  try {
    payload = JSON.parse(body) as SendSmsHookPayload;
  } catch {
    return hookError('Body was not JSON.', 400);
  }

  const phone = payload.user?.phone;
  const otp = payload.sms?.otp;
  if (!phone || !otp) {
    return hookError('Missing phone or otp.', 400);
  }

  // ---- console mode: spend nothing ---------------------------------------
  if (provider === 'console') {
    console.log(`[njiani] SMS_PROVIDER=console — code for ${phone} is ${otp}`);
    return json({}, 200);
  }

  if (provider !== 'beem') {
    console.error(`Unknown SMS_PROVIDER "${provider}".`);
    return hookError(`Unknown SMS provider "${provider}".`);
  }

  // ---- Beem ---------------------------------------------------------------
  const apiKey = Deno.env.get('BEEM_API_KEY');
  const secretKey = Deno.env.get('BEEM_SECRET_KEY');
  const senderId = Deno.env.get('BEEM_SENDER_ID');

  if (!apiKey || !secretKey || !senderId) {
    console.error('Beem credentials are missing.');
    return hookError('SMS gateway is not configured.');
  }

  const auth = btoa(`${apiKey}:${secretKey}`);
  const abort = AbortSignal.timeout(BEEM_TIMEOUT_MS);

  let response: Response;
  try {
    response = await fetch(BEEM_SEND_URL, {
      method: 'POST',
      signal: abort,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Basic ${auth}`,
      },
      body: JSON.stringify({
        source_addr: senderId,
        schedule_time: '',
        encoding: 0,
        message: messageFor(otp),
        recipients: [{ recipient_id: 1, dest_addr: toBeemAddress(phone) }],
      }),
    });
  } catch (error) {
    console.error('Could not reach Beem:', error);
    return hookError('Could not reach the SMS gateway.');
  }

  const text = await response.text();

  if (!response.ok) {
    // The provider's error is worth keeping; a live login code is not, so it
    // is never logged on this path.
    console.error(`Beem rejected the send (${response.status}): ${text}`);
    return hookError(`SMS gateway returned ${response.status}.`);
  }

  // One line per send, so the pilot's SMS spend is countable. No code, no
  // message body — just that one went to this number.
  console.log(`[njiani] sent a code to ${phone} via Beem`);

  return json({}, 200);
});
