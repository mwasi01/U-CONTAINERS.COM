import { jsonResponse, notFound } from '../../../../src/errors.js';
import { db } from '../../../../src/db.js';
export async function onRequestGet(ctx) {
  const b = await db(ctx.env).first('SELECT * FROM branches WHERE id = ?', ctx.params.id);
  if (!b) throw notFound();
  return jsonResponse(b);
}
