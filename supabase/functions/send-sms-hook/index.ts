// Supabase "Send SMS" auth hook — delivers Njiani's login codes through Beem.
//
// WHAT THIS DOES AND DOES NOT DO
//
// Supabase Auth generates the code, decides whether a submitted code is
// correct, caps the attempts and issues the session. This function only
// *delivers* the message. Beem never learns whether a code was accepted, and
// nothing here can authenticate anybody.
//
// That split is deliberate. Beem also sells a hosted OTP product that verifies
// codes itself; using it would mean bridging Beem's verdict into a Supabase
// session by hand, which is exactly the kind of home-made auth that should not
// exist in a ride-hailing app.
//
// WIRING IT UP (Dashboard → Authentication → Hooks → Send SMS hook)
//
//   1. supabase secrets set BEEM_API_KEY=... BEEM_SECRET_KEY=... \
//        BEEM_SENDER_ID=NJIANI SEND_SMS_HOOK_SECRET=v1,whsec_...
//   2. supabase functions deploy send-sms-hook --no-verify-jwt
//   3. Point the hook at the deployed URL and paste the same signing secret.
//
// `--no-verify-jwt` is required: Auth calls this before any user exists, so
// there is no JWT to verify. The request is authenticated by the Standard
// Webhooks signature instead, which is checked below.
//
// Set SMS_PROVIDER=console to log the code and send nothing. That is enough to
// build and test the whole sign-in flow at zero cost, and is the default here
// precisely so a misconfiguration cannot quietly start spending money.

import { createHmac, timingSafeEqual } from 'node:crypto';

const BEEM_SEND_URL = 'https://apisms.beem.africa/v1/send';

interface SendSmsHookPayload {
  user: { id: string; phone: string };
  sms: { otp: string };
}

/// Verifies the Standard Webhooks signature Supabase sends.
///
/// Without this, anyone who learned the function's URL could make Njiani send
/// SMS at Njiani's expense. Compared in constant time so a wrong signature
/// cannot be narrowed down by timing.
function signatureIsValid(
  secret: string,
  id: string,
  timestamp: string,
  body: string,
  header: string,
): boolean {
  // The dashboard shows the secret as `v1,whsec_<base64>`; the signing key is
  // the base64 part.
  const base64Key = secret.replace(/^v1,\s*/, '').replace(/^whsec_/, '');
  const key = Buffer.from(base64Key, 'base64');

  const expected = createHmac('sha256', key)
    .update(`${id}.${timestamp}.${body}`)
    .digest('base64');

  // The header may carry several space-separated versioned signatures.
  for (const part of header.split(' ')) {
    const [version, value] = part.split(',');
    if (version !== 'v1' || !value) continue;
    const a = Buffer.from(value);
    const b = Buffer.from(expected);
    if (a.length === b.length && timingSafeEqual(a, b)) return true;
  }
  return false;
}

/// Beem wants a bare international number: `255712345678`, no plus.
function toBeemAddress(e164: string): string {
  return e164.replace(/\D/g, '');
}

/// The message body.
///
/// Short on purpose: one SMS segment is 160 GSM-7 characters, and anything
/// longer is billed as two. The sender ID already says NJIANI, so the text
/// does not repeat it.
function messageFor(otp: string): string {
  return `${otp} ni namba yako ya Njiani. Usimpe mtu mwingine.\n`
    + `${otp} is your Njiani code. Do not share it.`;
}

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const body = await request.text();

  // ---- authenticate the caller -------------------------------------------
  const hookSecret = Deno.env.get('SEND_SMS_HOOK_SECRET');
  if (!hookSecret) {
    console.error('SEND_SMS_HOOK_SECRET is not set; refusing to send.');
    return new Response(
      JSON.stringify({ error: { message: 'Hook is not configured.' } }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const id = request.headers.get('webhook-id') ?? '';
  const timestamp = request.headers.get('webhook-timestamp') ?? '';
  const signature = request.headers.get('webhook-signature') ?? '';

  if (!signatureIsValid(hookSecret, id, timestamp, body, signature)) {
    console.error('Rejected a request with a bad webhook signature.');
    return new Response('Unauthorized', { status: 401 });
  }

  // ---- read the payload ---------------------------------------------------
  let payload: SendSmsHookPayload;
  try {
    payload = JSON.parse(body) as SendSmsHookPayload;
  } catch {
    return new Response('Bad request', { status: 400 });
  }

  const phone = payload.user?.phone;
  const otp = payload.sms?.otp;
  if (!phone || !otp) {
    return new Response(
      JSON.stringify({ error: { message: 'Missing phone or otp.' } }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const provider = Deno.env.get('SMS_PROVIDER') ?? 'console';

  // ---- console mode: spend nothing ---------------------------------------
  if (provider === 'console') {
    console.log(`[njiani] SMS_PROVIDER=console — code for ${phone} is ${otp}`);
    return new Response('{}', {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  if (provider !== 'beem') {
    console.error(`Unknown SMS_PROVIDER "${provider}".`);
    return new Response(
      JSON.stringify({ error: { message: 'Unknown SMS provider.' } }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  // ---- Beem ---------------------------------------------------------------
  const apiKey = Deno.env.get('BEEM_API_KEY');
  const secretKey = Deno.env.get('BEEM_SECRET_KEY');
  const senderId = Deno.env.get('BEEM_SENDER_ID');

  if (!apiKey || !secretKey || !senderId) {
    console.error('Beem credentials are missing.');
    return new Response(
      JSON.stringify({ error: { message: 'SMS gateway is not configured.' } }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const auth = Buffer.from(`${apiKey}:${secretKey}`).toString('base64');

  let response: Response;
  try {
    response = await fetch(BEEM_SEND_URL, {
      method: 'POST',
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
    // 500 makes Supabase report the failure to the app, which shows "no
    // connection" rather than leaving someone waiting for a code that was
    // never sent.
    return new Response(
      JSON.stringify({ error: { message: 'Could not reach the SMS gateway.' } }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  const text = await response.text();

  if (!response.ok) {
    // The code itself is never logged in this branch: a provider error is
    // worth keeping, a live login code is not.
    console.error(`Beem rejected the send (${response.status}): ${text}`);
    return new Response(
      JSON.stringify({ error: { message: 'The SMS could not be sent.' } }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  // One line per send, so the pilot's SMS spend is countable. No code, no
  // message body -- just that one went to this number.
  console.log(`[njiani] sent a code to ${phone} via Beem`);

  return new Response('{}', {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});
