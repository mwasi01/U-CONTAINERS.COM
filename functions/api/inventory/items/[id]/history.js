import { db } from '../../../../../src/db.js';
import { jsonResponse } from '../../../../../src/errors.js';
export async function onRequestGet(ctx) {
  return jsonResponse(await db(ctx.env).all(
    'SELECT * FROM inventory_adjustments WHERE item_id = ? ORDER BY created_at DESC',
    ctx.params.id));
}
