import { db } from '../../../src/db.js';
import { jsonResponse } from '../../../src/errors.js';
export async function onRequestGet(ctx) {
  const url = new URL(ctx.request.url);
  const branch = url.searchParams.get('branch');
  const category = url.searchParams.get('category');
  const d = db(ctx.env);
  let sql = 'SELECT * FROM products WHERE deleted_at IS NULL';
  const params = [];
  if (category) { sql += ' AND category_slug = ?'; params.push(category); }
  sql += ' ORDER BY created_at DESC LIMIT 100';
  return jsonResponse(await d.all(sql, ...params));
}
