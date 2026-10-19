import { db } from '../../../src/db.js';
import { jsonResponse } from '../../../src/errors.js';
export async function onRequestGet(ctx) {
  return jsonResponse(await db(ctx.env).all('SELECT * FROM inventory_transfers ORDER BY created_at DESC'));
}
