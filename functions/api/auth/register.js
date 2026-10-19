import { db } from '../../../src/db.js';
import { hashPassword, signJWT } from '../../../src/auth.js';
import { uuid, nowISO } from '../../../src/utils.js';
import { jsonResponse, badRequest } from '../../../src/errors.js';

export async function onRequestPost(ctx) {
  const body = await ctx.request.json().catch(() => null);
  if (!body?.email || !body?.password || !body?.name) throw badRequest('email, password, name required');

  const d = db(ctx.env);
  const existing = await d.first('SELECT id FROM users WHERE email = ?', body.email);
  if (existing) throw badRequest('Email already registered');

  const id = uuid();
  const hash = await hashPassword(body.password);
  await d.run(
    `INSERT INTO users (id, email, password_hash, name, role, created_at, updated_at)
     VALUES (?, ?, ?, ?, 'customer', ?, ?)`,
    id, body.email, hash, body.name, nowISO(), nowISO()
  );
  const token = await signJWT({ sub: id, email: body.email, role: 'customer' }, ctx.env.JWT_SECRET);
  return jsonResponse({ token, user: { id, email: body.email, name: body.name, role: 'customer' } });
}
