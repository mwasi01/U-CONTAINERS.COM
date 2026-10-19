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
  const period = url.searchParams.get('period') || 'day';
  const requestedBranch = url.searchParams.get('branch') || null;
  const branchFilter = scopedBranchId(user, requestedBranch);

  const d = db(ctx.env);

  let groupExpr;
  switch (period) {
    case 'week':  groupExpr = "strftime('%Y-%W', created_at)"; break;
    case 'month': groupExpr = "strftime('%Y-%m', created_at)"; break;
    case 'year':  groupExpr = "strftime('%Y', created_at)";    break;
    default:      groupExpr = "strftime('%Y-%m-%d', created_at)"; break;
  }

  const limitMap = { day: 30, week: 12, month: 12, year: 5 };
  const limit = limitMap[period] || 30;

  const whereBranch = branchFilter ? ' AND branch_id = ?' : '';
  const branchParams = branchFilter ? [branchFilter] : [];

  const rows = await d.all(
    `SELECT
       ${groupExpr} AS label,
       COUNT(*) AS orders,
       COALESCE(SUM(total), 0) AS revenue
     FROM orders
     WHERE created_at IS NOT NULL${whereBranch}
     GROUP BY label
     ORDER BY label DESC
     LIMIT ${limit}`,
    ...branchParams
  );

  const series = rows.reverse().map((r) => ({
    label: r.label || '',
    orders: Number(r.orders || 0),
    revenue: Number(r.revenue || 0),
  }));

  const profitRows = await d.all(
    `SELECT
       ${groupExpr.replace(/created_at/g, 'o.created_at')} AS label,
       COALESCE(SUM((oi.price - COALESCE(p.cost, 0)) * oi.qty), 0) AS profit
     FROM orders o
     JOIN order_items oi ON oi.order_id = o.id
     LEFT JOIN products p ON p.id = oi.product_id
     WHERE o.created_at IS NOT NULL${branchFilter ? ' AND o.branch_id = ?' : ''}
     GROUP BY label
     ORDER BY label DESC
     LIMIT ${limit}`,
    ...branchParams
  );

  const profitByLabel = {};
  for (const r of profitRows) profitByLabel[r.label] = Number(r.profit || 0);

  const withProfit = series.map((s) => ({ ...s, profit: profitByLabel[s.label] || 0 }));

  const totalRevenue = withProfit.reduce((sum, s) => sum + s.revenue, 0);
  const totalProfit = withProfit.reduce((sum, s) => sum + s.profit, 0);
  const totalOrders = withProfit.reduce((sum, s) => sum + s.orders, 0);
  const avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;

  return jsonResponse({
    period,
    branch: branchFilter,
    series: withProfit,
    totals: { revenue: totalRevenue, profit: totalProfit, orders: totalOrders, avgOrderValue },
  });
}
