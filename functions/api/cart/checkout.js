import { uuid, nowISO } from '../../../src/utils.js';
import { db } from '../../../src/db.js';
import { jsonResponse, badRequest } from '../../../src/errors.js';

export async function onRequestPost(ctx) {
  const body = await ctx.request.json().catch(() => null);
  if (!body?.items?.length) throw badRequest('Cart is empty');
  const d = db(ctx.env);
  const orderId = uuid();
  await d.run(
    `INSERT INTO orders (id, customer_id, status, total, created_at) VALUES (?, ?, 'pending', ?, ?)`,
    orderId, body.customer?.email || null, 0, nowISO()
  );
  return jsonResponse({ orderId });
}
