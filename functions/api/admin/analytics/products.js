import { db } from '../../../../src/db.js';
import { jsonResponse, forbidden } from '../../../../src/errors.js';
import { getAuthUser } from '../../../../src/auth.js';

const EDIT_ROLES = ['owner', 'admin', 'manager'];

async function requireEditor(ctx) {
  let user = ctx.data?.user;
  if (!user) {
    user = await getAuthUser(ctx);
    if (user) ctx.data.user = user;
  }
  if (!user || !EDIT_ROLES.includes(user.role)) throw forbidden('Admin access only');
  return user;
}

// GET /api/admin/analytics/products
export async function onRequestGet(ctx) {
  await requireEditor(ctx);
  const d = db(ctx.env);

  // Top products by units sold
  const topProducts = await d.all(`
    SELECT
      oi.product_id AS id,
      oi.name AS name,
      COALESCE(p.category_slug, 'uncategorised') AS category,
      SUM(oi.qty) AS units_sold,
      SUM(oi.qty * oi.price) AS revenue,
      SUM(oi.qty * COALESCE(p.cost, 0)) AS total_cost,
      SUM(oi.qty * (oi.price - COALESCE(p.cost, 0))) AS profit
    FROM order_items oi
    LEFT JOIN products p ON p.id = oi.product_id
    GROUP BY oi.product_id, oi.name
    ORDER BY units_sold DESC
    LIMIT 10
  `);

  // Revenue share by category
  const categoryBreakdown = await d.all(`
    SELECT
      COALESCE(p.category_slug, 'uncategorised') AS category,
      SUM(oi.qty * oi.price) AS revenue
    FROM order_items oi
    LEFT JOIN products p ON p.id = oi.product_id
    GROUP BY category
    ORDER BY revenue DESC
  `);

  return jsonResponse({
    topProducts: topProducts.map((p) => ({
      id: p.id,
      name: p.name,
      category: p.category,
      unitsSold: Number(p.units_sold || 0),
      revenue: Number(p.revenue || 0),
      cost: Number(p.total_cost || 0),
      profit: Number(p.profit || 0),
    })),
    categoryBreakdown: categoryBreakdown.map((c) => ({
      category: c.category,
      revenue: Number(c.revenue || 0),
    })),
  });
}
