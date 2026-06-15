// Minimal App Store Connect API client. Signs an ES256 JWT from the .p8 key
// (no external deps — Node's crypto does ECDSA P-256). Usage:
//   ASC_ISSUER_ID=<uuid> node scripts/asc.mjs <METHOD> <path> [jsonBody]
// e.g. node scripts/asc.mjs GET "/v1/apps?filter[bundleId]=ai.palmr.emma"
import crypto from 'node:crypto';
import { readFileSync } from 'node:fs';
import os from 'node:os';

const KEY_ID = process.env.ASC_KEY_ID || '99L2CGPPWK';
const ISSUER = process.env.ASC_ISSUER_ID;
const KEY_PATH = process.env.ASC_KEY_PATH || `${os.homedir()}/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8`;
if (!ISSUER) { console.error('Set ASC_ISSUER_ID'); process.exit(2); }

function b64url(buf) {
  return Buffer.from(buf).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

export function token() {
  const header = { alg: 'ES256', kid: KEY_ID, typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const payload = { iss: ISSUER, iat: now, exp: now + 600, aud: 'appstoreconnect-v1' };
  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const key = readFileSync(KEY_PATH, 'utf8');
  const sig = crypto.sign('SHA256', Buffer.from(signingInput), { key, dsaEncoding: 'ieee-p1363' });
  return `${signingInput}.${b64url(sig)}`;
}

export async function asc(method, path, body) {
  const res = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
    method,
    headers: { Authorization: `Bearer ${token()}`, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json; try { json = JSON.parse(text); } catch { json = text; }
  return { status: res.status, json };
}

// CLI
if (import.meta.url === `file://${process.argv[1]}`) {
  const [, , method = 'GET', path = '/v1/apps?limit=5', bodyArg] = process.argv;
  const body = bodyArg ? JSON.parse(bodyArg) : undefined;
  const { status, json } = await asc(method, path, body);
  console.log(status);
  console.log(JSON.stringify(json, null, 2));
}
