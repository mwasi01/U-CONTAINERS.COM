import { db } from '../../../../../src/db.js';
import { jsonResponse } from '../../../../../src/errors.js';
export async function onRequestGet(ctx) {
  return jsonResponse(await db(ctx.env).all('SELECT * FROM staff_assignments WHERE user_id = ?', ctx.params.id));
}
