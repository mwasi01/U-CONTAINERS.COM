import { db } from '../../../src/db.js';
import { jsonResponse, notFound } from '../../../src/errors.js';
export async function onRequestGet(ctx) {
  const c = await db(ctx.env).first('SELECT * FROM customers WHERE id = ?', ctx.params.id);
  if (!c) throw notFound();
  return jsonResponse(c);
}
