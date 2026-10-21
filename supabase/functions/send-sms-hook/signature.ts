// Standard Webhooks signature verification, in pure Web Crypto.
//
// No imports. Earlier this used `node:crypto` and a bare `Buffer`, neither of
// which is guaranteed in Deno -- `Buffer` is not a global there at all. A
// module that fails to boot never answers, and Supabase reports that as
// "Gateway Timeout", which is what sent us looking in the wrong place.
//
// Everything here (`crypto.subtle`, `atob`, `btoa`, `TextEncoder`) is a Web
// standard, present in Deno, in Supabase's edge runtime, and in Node 22 --
// which is what lets this file be tested outside Deno.

/// Decodes base64 to bytes.
export function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/// Encodes bytes as base64.
export function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

/// Strips the `v1,` prefix and the `whsec_` marker the dashboard shows.
export function signingKeyOf(secret: string): string {
  return secret.replace(/^v1,\s*/, '').replace(/^whsec_/, '').trim();
}

/// The expected signature for one delivery.
export async function expectedSignature(
  secret: string,
  id: string,
  timestamp: string,
  body: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    base64ToBytes(signingKeyOf(secret)),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signed = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(`${id}.${timestamp}.${body}`),
  );
  return bytesToBase64(new Uint8Array(signed));
}

/// Compares two strings without leaking where they first differ.
///
/// A plain `===` returns as soon as it finds a mismatch, which lets an
/// attacker narrow a signature one character at a time.
export function constantTimeEquals(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/// Whether [header] carries a valid signature for this delivery.
///
/// The header may hold several space-separated versioned signatures, so that
/// a secret can be rotated without dropping deliveries.
export async function isSignatureValid(
  secret: string,
  id: string,
  timestamp: string,
  body: string,
  header: string,
): Promise<boolean> {
  let expected: string;
  try {
    expected = await expectedSignature(secret, id, timestamp, body);
  } catch {
    // A malformed secret must fail closed, not throw and take the whole
    // request down as a timeout.
    return false;
  }

  for (const part of header.trim().split(/\s+/)) {
    const comma = part.indexOf(',');
    if (comma < 0) continue;
    const version = part.slice(0, comma);
    const value = part.slice(comma + 1);
    if (version !== 'v1' || !value) continue;
    if (constantTimeEquals(value, expected)) return true;
  }
  return false;
}
