import { db } from '../../../src/db.js';
import { jsonResponse } from '../../../src/errors.js';

export async function onRequestGet(ctx) {
  const user = ctx.data?.user;
  if (!user || !['owner', 'admin', 'manager'].includes(user.role)) {
    return new Response(JSON.stringify({ data: null, error: { code: 'forbidden', message: 'Admin access only' } }), {
      status: 403, headers: { 'Content-Type': 'application/json' },
    });
  }

  const d = db(ctx.env);

  const [
    products,
    users,
    orders,
    messages,
    branches,
  ] = await Promise.all([
    d.first('SELECT COUNT(*) AS n FROM products WHERE deleted_at IS NULL'),
    d.first('SELECT COUNT(*) AS n FROM users WHERE deleted_at IS NULL'),
    d.first('SELECT COUNT(*) AS n, COALESCE(SUM(total),0) AS total FROM orders'),
    d.first('SELECT COUNT(*) AS n FROM contact_messages WHERE status = "new"'),
    d.all('SELECT id, name, slug FROM branches'),
  ]);

  const recentOrders = await d.all(
    'SELECT id, customer_id, total, status, created_at FROM orders ORDER BY created_at DESC LIMIT 10'
  );

  const recentMessages = await d.all(
    'SELECT id, name, email, subject, status, created_at FROM contact_messages ORDER BY created_at DESC LIMIT 10'
  );

  return jsonResponse({
    stats: {
      products: Number(products?.n || 0),
      users: Number(users?.n || 0),
      orders: Number(orders?.n || 0),
      revenue: Number(orders?.total || 0),
      newMessages: Number(messages?.n || 0),
      branches: branches.length,
    },
    recentOrders,
    recentMessages,
    branches,
  });
}
