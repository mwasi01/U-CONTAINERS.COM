import { signJWT, verifyJWT } from './auth.js';
const PREFIX = 'sess:';

export async function createSession(env, userId, meta = {}) {
  const token = await signJWT({ sub: userId, ...meta }, env.JWT_SECRET || 'dev-secret');
  await env.KV.put(PREFIX + token, JSON.stringify({ userId, ...meta }), { expirationTtl: 604800 });
  return token;
}
export async function destroySession(env, token) { await env.KV.delete(PREFIX + token); }
export { verifyJWT };
