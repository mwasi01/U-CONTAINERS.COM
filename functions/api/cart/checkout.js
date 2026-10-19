import { uuid, nowISO } from '../../../src/utils.js';
import { db } from '../../../src/db.js';
import { jsonResponse, badRequest, serverError } from '../../../src/errors.js';
import { getAuthUser } from '../../../src/auth.js';

export async function onRequestPost(ctx) {
  const body = await ctx.request.json().catch(() => null);
  if (!body?.items?.length) throw badRequest('Cart is empty');

  const d = db(ctx.env);
  const user = await getAuthUser(ctx);

  const customer = body.customer || {};
  const items = body.items.map((i) => ({
    id: String(i.id),
    name: String(i.name || 'Item'),
    qty: Math.max(1, Number(i.qty) || 1),
    price: Math.max(0, Number(i.price) || 0),
  }));

  const total = items.reduce((sum, i) => sum + i.qty * i.price, 0);
  const orderId = uuid();
  const now = nowISO();

  try {
    await d.run(
      `INSERT INTO orders (id, customer_id, branch_id, status, total, created_at, updated_at)
       VALUES (?, ?, ?, 'pending', ?, ?, ?)`,
      orderId,
      customer.email || null,
      customer.branch || null,
      total,
      now,
      now
    );

    for (const item of items) {
      await d.run(
        `INSERT INTO order_items (id, order_id, product_id, name, qty, price)
         VALUES (?, ?, ?, ?, ?, ?)`,
        uuid(),
        orderId,
        item.id.startsWith('p_') ? item.id : null,
        item.name,
        item.qty,
        item.price
      );
    }

    if (customer.email) {
      try {
        await d.run(
          `INSERT INTO customers (id, user_id, email, name, phone, created_at)
           VALUES (?, ?, ?, ?, ?, ?)`,
          uuid(),
          user?.sub || null,
          customer.email,
          customer.name || null,
          customer.phone || null,
          now
        );
      } catch { /* customer already exists or schema mismatch — order is still valid */ }
    }

    return jsonResponse({ orderId, total, items: items.length });
  } catch (err) {
    console.error('checkout failed', err);
    throw serverError('Could not create order: ' + err.message);
  }
}
