import { db } from '../../../src/db.js';
import { jsonResponse, notFound } from '../../../src/errors.js';
export async function onRequestGet(ctx) {
  const t = await db(ctx.env).first('SELECT * FROM inventory_transfers WHERE id = ?', ctx.params.id);
  if (!t) throw notFound();
  return jsonResponse(t);
}
