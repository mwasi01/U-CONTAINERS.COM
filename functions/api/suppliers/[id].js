import { db } from '../../../src/db.js';
import { jsonResponse, notFound } from '../../../src/errors.js';
export async function onRequestGet(ctx) {
  const s = await db(ctx.env).first('SELECT * FROM suppliers WHERE id = ?', ctx.params.id);
  if (!s) throw notFound();
  return jsonResponse(s);
}
