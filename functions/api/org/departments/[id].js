import { db } from '../../../../src/db.js';
import { jsonResponse, notFound } from '../../../../src/errors.js';
export async function onRequestGet(ctx) {
  const row = await db(ctx.env).first('SELECT * FROM departments WHERE id = ?', ctx.params.id);
  if (!row) throw notFound();
  return jsonResponse(row);
}
