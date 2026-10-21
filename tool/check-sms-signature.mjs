// Checks the Send-SMS hook's webhook signature against an independently
// computed HMAC.
//
// The hook's signature.ts is written in pure Web Crypto so it can be verified
// here, in Node, without a Deno runtime. That matters: a mistake in this file
// means either that Njiani rejects real deliveries, or that anyone who learns
// the function's URL can spend Njiani's SMS credit.
//
//   node tool/check-sms-signature.mjs
//
// Run automatically by ./tool/check.sh.

import { createHmac } from 'node:crypto';
import { readFileSync } from 'node:fs';

const path = process.argv[2] ?? 'supabase/functions/send-sms-hook/signature.ts';

// Strip the TypeScript annotations so Node can import the module directly.
// Crude, and sufficient: this file is deliberately plain.
const source = readFileSync(path, 'utf8')
  .replace(/: *Uint8Array/g, '')
  .replace(/: *string/g, '')
  .replace(/: *Promise<[^>]+>/g, '')
  .replace(/: *boolean/g, '')
  .replace(/export /g, '');

const mod = await import(
  'data:text/javascript,' + encodeURIComponent(
    source +
    '\nexport {expectedSignature, isSignatureValid, constantTimeEquals, signingKeyOf};',
  )
);

const secret = 'v1,whsec_' +
  Buffer.from('njiani-test-signing-key-0123456789').toString('base64');
const id = 'msg_2abc';
const ts = '1729512345';
const body = JSON.stringify({
  user: { phone: '+255712345678' },
  sms: { otp: '123456' },
});

const failures = [];
const check = (label, actual, expected = true) => {
  const ok = actual === expected;
  if (!ok) failures.push(`${label}: expected ${expected}, got ${actual}`);
  console.log(`${ok ? '  ok  ' : '  FAIL'} ${label}`);
};

// The reference, per the Standard Webhooks spec, computed with Node's own
// HMAC rather than with the code under test.
const reference = createHmac('sha256', Buffer.from(mod.signingKeyOf(secret), 'base64'))
  .update(`${id}.${ts}.${body}`)
  .digest('base64');
const ours = await mod.expectedSignature(secret, id, ts, body);

check('matches an independently computed HMAC', ours === reference);
check('accepts a correct signature',
  await mod.isSignatureValid(secret, id, ts, body, `v1,${ours}`));
check('accepts one of several, so a secret can be rotated',
  await mod.isSignatureValid(secret, id, ts, body, `v1,wrong ${`v1,${ours}`}`));
check('rejects a wrong signature',
  await mod.isSignatureValid(secret, id, ts, body, 'v1,AAAA'), false);
check('rejects a tampered body',
  await mod.isSignatureValid(secret, id, ts, body + 'x', `v1,${ours}`), false);
check('rejects a tampered timestamp',
  await mod.isSignatureValid(secret, id, '1', body, `v1,${ours}`), false);
check('rejects an unknown signature version',
  await mod.isSignatureValid(secret, id, ts, body, `v2,${ours}`), false);
check('rejects an empty header',
  await mod.isSignatureValid(secret, id, ts, body, ''), false);
check('fails closed on a malformed secret, rather than throwing',
  await mod.isSignatureValid('not base64 !!', id, ts, body, `v1,${ours}`), false);
check('accepts the secret with or without its whsec_ prefix',
  mod.signingKeyOf(secret) === mod.signingKeyOf(secret.replace('v1,', '')));
check('constant-time compare is correct',
  mod.constantTimeEquals('abc', 'abc') &&
  !mod.constantTimeEquals('abc', 'abd') &&
  !mod.constantTimeEquals('ab', 'abc'));

console.log('');
if (failures.length) {
  console.error(`${failures.length} signature check(s) failed:`);
  for (const f of failures) console.error(`  ${f}`);
  process.exit(1);
}
console.log('All signature checks passed.');
