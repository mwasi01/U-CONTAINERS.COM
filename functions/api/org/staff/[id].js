import { db } from '../../../../src/db.js';
import { jsonResponse, notFound } from '../../../../src/errors.js';
export async function onRequestGet(ctx) {
  const u = await db(ctx.env).first('SELECT id, email, name, role FROM users WHERE id = ?', ctx.params.id);
  if (!u) throw notFound();
  return jsonResponse(u);
}
