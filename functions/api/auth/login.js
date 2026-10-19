import { db } from '../../../src/db.js';
import { verifyPassword, signJWT } from '../../../src/auth.js';
import { jsonResponse, unauthorized } from '../../../src/errors.js';

export async function onRequestPost(ctx) {
  const body = await ctx.request.json().catch(() => null);
  if (!body?.email || !body?.password) throw unauthorized('Missing credentials');

  const d = db(ctx.env);
  const user = await d.first('SELECT * FROM users WHERE email = ?', body.email);
  if (!user) throw unauthorized('Invalid credentials');

  const ok = await verifyPassword(body.password, user.password_hash);
  if (!ok) throw unauthorized('Invalid credentials');

  const token = await signJWT(
    { sub: user.id, email: user.email, role: user.role, branchId: user.branch_id },
    ctx.env.JWT_SECRET
  );
  return jsonResponse({ token, user: { id: user.id, email: user.email, name: user.name, role: user.role } });
}
