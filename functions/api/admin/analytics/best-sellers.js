import { db } from '../../../../src/db.js';
import { jsonResponse, forbidden } from '../../../../src/errors.js';
import { getAuthUser } from '../../../../src/auth.js';
import { scopedBranchId } from '../../../../src/branch-context.js';

const EDIT_ROLES = ['owner', 'admin', 'manager', 'supervisor'];

async function requireEditor(ctx) {
  let user = ctx.data?.user;
  if (!user) {
    user = await getAuthUser(ctx);
    if (user) ctx.data.user = user;
  }
  if (!user || !EDIT_ROLES.includes(user.role)) throw forbidden('Admin access only');
  return user;
}

export async function onRequestGet(ctx) {
  const user = await requireEditor(ctx);
  const url = new URL(ctx.request.url);
  const requestedBranch = url.searchParams.get('branch') || null;
  const branchFilter = scopedBranchId(user, requestedBranch);

  const d = db(ctx.env);
  const whereBranch = branchFilter ? ' AND o.branch_id = ?' : '';
  const branchParams = branchFilter ? [branchFilter] : [];

  const baseSql = `
    SELECT
      oi.product_id AS id,
      oi.name AS name,
      COALESCE(p.category_slug, 'uncategorised') AS category,
      SUM(oi.qty) AS units_sold,
      SUM(oi.qty * oi.price) AS revenue,
      SUM(oi.qty * COALESCE(p.cost, 0)) AS total_cost,
      SUM(oi.qty * (oi.price - COALESCE(p.cost, 0))) AS profit,
      CASE
        WHEN SUM(oi.qty * oi.price) > 0
        THEN ROUND(SUM(oi.qty * (oi.price - COALESCE(p.cost, 0))) / SUM(oi.qty * oi.price) * 100, 1)
        ELSE 0
      END AS margin_pct
    FROM order_items oi
    JOIN orders o ON o.id = oi.order_id
    LEFT JOIN products p ON p.id = oi.product_id
    WHERE 1=1${whereBranch}
    GROUP BY oi.product_id, oi.name
  `;

  const byUnits = await d.all(baseSql + ' ORDER BY units_sold DESC LIMIT 20', ...branchParams);
  const byProfit = await d.all(baseSql + ' ORDER BY profit DESC LIMIT 20', ...branchParams);

  const shape = (r) => ({
    id: r.id,
    name: r.name,
    category: r.category,
    unitsSold: Number(r.units_sold || 0),
    revenue: Number(r.revenue || 0),
    cost: Number(r.total_cost || 0),
    profit: Number(r.profit || 0),
    marginPct: Number(r.margin_pct || 0),
  });

  return jsonResponse({
    branch: branchFilter,
    byUnits: byUnits.map(shape),
    byProfit: byProfit.map(shape),
  });
}
