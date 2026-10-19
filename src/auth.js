const enc = new TextEncoder();
const b64url = (b) => btoa(String.fromCharCode(...b)).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');

async function key(secret) {
  return crypto.subtle.importKey('raw', enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}

export async function signJWT(payload, secret, expSeconds = 60 * 60 * 24 * 7) {
  const now = Math.floor(Date.now() / 1000);
  const body = { iat: now, exp: now + expSeconds, ...payload };
  const unsigned = `${b64url(enc.encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' })))}.${b64url(enc.encode(JSON.stringify(body)))}`;
  const sig = await crypto.subtle.sign('HMAC', await key(secret), enc.encode(unsigned));
  return `${unsigned}.${b64url(new Uint8Array(sig))}`;
}

export async function verifyJWT(token, secret) {
  const parts = token?.split('.');
  if (parts?.length !== 3) return null;
  const [h, p, s] = parts;
  const data = enc.encode(`${h}.${p}`);
  const sig = Uint8Array.from(atob(s.replace(/-/g,'+').replace(/_/g,'/')), (c) => c.charCodeAt(0));
  const ok = await crypto.subtle.verify('HMAC', await key(secret), sig, data);
  if (!ok) return null;
  try {
    const payload = JSON.parse(atob(p.replace(/-/g,'+').replace(/_/g,'/')));
    return payload.exp && payload.exp < Math.floor(Date.now() / 1000) ? null : payload;
  } catch { return null; }
}

export async function hashPassword(password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const k = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations: 100000, hash: 'SHA-256' }, k, 256);
  return `pbkdf2$${b64url(salt)}$${b64url(new Uint8Array(bits))}`;
}

export async function verifyPassword(password, stored) {
  const [algo, saltB64, hashB64] = (stored || '').split('$');
  if (algo !== 'pbkdf2') return false;
  const salt = Uint8Array.from(atob(saltB64.replace(/-/g,'+').replace(/_/g,'/')), (c) => c.charCodeAt(0));
  const k = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations: 100000, hash: 'SHA-256' }, k, 256);
  return b64url(new Uint8Array(bits)) === hashB64;
}

export async function getAuthUser(ctx) {
  const auth = ctx.request.headers.get('Authorization') || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : null;
  if (!token) return null;
  return verifyJWT(token, ctx.env.JWT_SECRET || 'dev-secret');
}

export async function requireAuth(ctx) {
  const u = await getAuthUser(ctx);
  if (!u) throw new Error('Unauthorized');
  return u;
}
