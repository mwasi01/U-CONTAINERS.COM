import { db } from '../../../src/db.js';
import { jsonResponse, notFound } from '../../../src/errors.js';
export async function onRequestGet(ctx) {
  const p = await db(ctx.env).first('SELECT * FROM products WHERE id = ? AND deleted_at IS NULL', ctx.params.id);
  if (!p) throw notFound();
  return jsonResponse(p);
}
