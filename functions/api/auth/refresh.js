import { signJWT } from '../../../src/auth.js';
import { jsonResponse, unauthorized } from '../../../src/errors.js';
export async function onRequestPost(ctx) {
  const u = ctx.data.user;
  if (!u) throw unauthorized();
  return jsonResponse({ token: await signJWT({ sub: u.sub, role: u.role }, ctx.env.JWT_SECRET) });
}
