import { db } from '../../../src/db.js';
import { jsonResponse } from '../../../src/errors.js';
export async function onRequestGet(ctx) {
  const q = new URL(ctx.request.url).searchParams.get('q') || '';
  return jsonResponse(await db(ctx.env).all(
    'SELECT * FROM products WHERE name LIKE ? LIMIT 50', `%${q}%`));
}
