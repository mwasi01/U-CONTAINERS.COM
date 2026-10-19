import { db } from '../../../../src/db.js';
import { jsonResponse } from '../../../../src/errors.js';
export async function onRequestGet(ctx) {
  return jsonResponse(await db(ctx.env).all('SELECT id, email, name, role FROM users WHERE role != "customer"'));
}
