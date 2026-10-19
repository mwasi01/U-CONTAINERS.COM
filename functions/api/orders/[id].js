import { db } from '../../../src/db.js';
import { jsonResponse, notFound } from '../../../src/errors.js';
export async function onRequestGet(ctx) {
  const o = await db(ctx.env).first('SELECT * FROM orders WHERE id = ?', ctx.params.id);
  if (!o) throw notFound();
  return jsonResponse(o);
}
