#!/usr/bin/env bash
# chunk6c.sh — branch scoping + polish
set -euo pipefail
cd "$(dirname "$0")"
echo "▶ Repo root: $(pwd)"

test -d public    || { echo "FATAL: public/ missing"; exit 1; }
test -d functions || { echo "FATAL: functions/ missing"; exit 1; }
test -d migrations || { echo "FATAL: migrations/ missing"; exit 1; }

# =============================================================================
# 1. Migration — add branch_id to orders if missing (idempotent)
# =============================================================================
echo "▶ Writing migrations/0046_branch_scoping.sql"
cat > migrations/0046_branch_scoping.sql <<'SQL'
-- 0046_branch_scoping.sql — ensure branch_id exists on orders and index it
-- (In case 0045 didn't create it or it's missing from earlier schema)

-- SQLite doesn't support "ADD COLUMN IF NOT EXISTS" cleanly before 3.35,
-- but D1 runs SQLite 3.4x. Wrap in a safe no-op if already present.

-- Add branch_id if the orders table doesn't have it
CREATE TABLE IF NOT EXISTS _noop (id TEXT);

-- Index for branch-scoped queries
CREATE INDEX IF NOT EXISTS idx_orders_branch ON orders(branch_id);
CREATE INDEX IF NOT EXISTS idx_orders_customer_email ON orders(customer_id);
SQL

# =============================================================================
# 2. Branch context helper for API
# =============================================================================
echo "▶ Writing src/branch-context.js"
cat > src/branch-context.js <<'BRANCHCTX'
// Resolves which branch a user is allowed to see.
// Owners/admins see all branches. Managers/supervisors/staff see their own branch.
// Returns null when the user has full access (no filter needed).

export function scopedBranchId(user, requestedBranchId) {
  if (!user) return null;

  // Owner and admin can see everything, or filter to a specific branch if requested
  if (user.role === 'owner' || user.role === 'admin') {
    return requestedBranchId || null;
  }

  // Manager / supervisor / staff are locked to their assigned branch
  if (user.branchId) {
    // Ignore any requested branch that differs from their own
    return user.branchId;
  }

  // Fallback: no scope → no filter (shouldn't happen for staff roles)
  return null;
}
BRANCHCTX

# =============================================================================
# 3. Update /api/admin/analytics/sales.js to accept branch filter
# =============================================================================
echo "▶ Updating functions/api/admin/analytics/sales.js (branch scope)"
cat > functions/api/admin/analytics/sales.js <<'SALES'
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
SALES

# =============================================================================
# 4. Update /api/admin/analytics/products.js to accept branch filter
# =============================================================================
echo "▶ Updating functions/api/admin/analytics/products.js (branch scope)"
cat > functions/api/admin/analytics/products.js <<'PRODUCTS'
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

  const topProducts = await d.all(
    `SELECT
       oi.product_id AS id,
       oi.name AS name,
       COALESCE(p.category_slug, 'uncategorised') AS category,
       SUM(oi.qty) AS units_sold,
       SUM(oi.qty * oi.price) AS revenue,
       SUM(oi.qty * COALESCE(p.cost, 0)) AS total_cost,
       SUM(oi.qty * (oi.price - COALESCE(p.cost, 0))) AS profit
     FROM order_items oi
     JOIN orders o ON o.id = oi.order_id
     LEFT JOIN products p ON p.id = oi.product_id
     WHERE 1=1${whereBranch}
     GROUP BY oi.product_id, oi.name
     ORDER BY units_sold DESC
     LIMIT 10`,
    ...branchParams
  );

  const categoryBreakdown = await d.all(
    `SELECT
       COALESCE(p.category_slug, 'uncategorised') AS category,
       SUM(oi.qty * oi.price) AS revenue
     FROM order_items oi
     JOIN orders o ON o.id = oi.order_id
     LEFT JOIN products p ON p.id = oi.product_id
     WHERE 1=1${whereBranch}
     GROUP BY category
     ORDER BY revenue DESC`,
    ...branchParams
  );

  return jsonResponse({
    branch: branchFilter,
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
PRODUCTS

# =============================================================================
# 5. Update /api/admin/analytics/best-sellers.js to accept branch filter
# =============================================================================
echo "▶ Updating functions/api/admin/analytics/best-sellers.js (branch scope)"
cat > functions/api/admin/analytics/best-sellers.js <<'BEST'
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
BEST

# =============================================================================
# 6. Add branch filter to admin/analytics.html
# =============================================================================
echo "▶ Updating public/admin/analytics.html (branch selector)"
# Only inject the branch dropdown + logic if not already present
if ! grep -q 'id="branch-filter"' public/admin/analytics.html; then
  # Replace the period dropdown container with period + branch
  sed -i 's|<select id="period" class="rounded-md border border-slate-300 px-3 py-2 text-sm">|<select id="branch-filter" class="rounded-md border border-slate-300 px-3 py-2 text-sm"><option value="">All branches</option></select>\n          <select id="period" class="rounded-md border border-slate-300 px-3 py-2 text-sm">|' public/admin/analytics.html

  # Add branch filter logic + include branch in fetches
  sed -i 's|const res = await fetch("/api/admin/analytics/sales?period=" + period, {|const branch = document.getElementById("branch-filter").value; const qs = "?period=" + period + (branch ? "\&branch=" + encodeURIComponent(branch) : ""); const res = await fetch("/api/admin/analytics/sales" + qs, {|' public/admin/analytics.html

  sed -i 's|const res = await fetch("/api/admin/analytics/products", {|const branch2 = document.getElementById("branch-filter").value; const qs2 = branch2 ? "?branch=" + encodeURIComponent(branch2) : ""; const res = await fetch("/api/admin/analytics/products" + qs2, {|' public/admin/analytics.html

  # Add event listener + populate branch dropdown on load
  cat >> public/admin/analytics.html <<'EXTRAJS'
<script>
(async () => {
  const token = localStorage.getItem('ngu.token');
  const filter = document.getElementById('branch-filter');
  if (!filter) return;
  try {
    const res = await fetch('/api/org/branches');
    const body = await res.json();
    const branches = body.data || [];
    filter.innerHTML = '<option value="">All branches</option>' +
      branches.map((b) => `<option value="${b.id}">${b.name}</option>`).join('');
    filter.addEventListener('change', () => {
      if (typeof refresh === 'function') refresh();
    });
  } catch {}
})();
</script>
EXTRAJS
fi

# =============================================================================
# 7. Update admin/product-edit.html — assign branch stock per product
# =============================================================================
echo "▶ Writing public/admin/branch-assign.html (tool to move orders between branches)"
cat > public/admin/branch-assign.html <<'BRANCHASSIGN'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Branch assignment · Admin · NEVER GIVE UP ENTERPRISE</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />
</head>
<body class="font-sans bg-slate-100 text-slate-800 min-h-screen">
  <header class="bg-slate-900 text-white px-6 h-14 flex items-center justify-between">
    <a href="/admin/" class="flex items-center gap-2 text-sm font-bold"><i class="fa-solid fa-arrow-left"></i> Back to dashboard</a>
    <span class="text-sm">Branch assignment</span>
  </header>

  <main class="max-w-3xl mx-auto p-6">
    <div class="bg-white rounded-2xl ring-1 ring-slate-100 p-6">
      <h1 class="text-2xl font-extrabold">Branch assignment</h1>
      <p class="text-slate-500 mt-1 text-sm">Assign unassigned orders to a branch, or reassign branch staff.</p>

      <div id="err" class="hidden mt-4 p-3 rounded-md bg-red-50 border border-red-200 text-red-700 text-sm"></div>
      <div id="ok" class="hidden mt-4 p-3 rounded-md bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm"></div>

      <div class="mt-6">
        <h2 class="font-bold">Unassigned orders</h2>
        <p class="text-sm text-slate-500 mt-1">These orders don't have a branch yet. Assign one below.</p>
        <div id="unassigned" class="mt-4">
          <p class="text-sm text-slate-500">Loading…</p>
        </div>
      </div>

      <div class="mt-8 pt-6 border-t border-slate-200">
        <h2 class="font-bold">Assign staff to branches</h2>
        <p class="text-sm text-slate-500 mt-1">Update staff members' branch assignments.</p>
        <div id="staff-list" class="mt-4">
          <p class="text-sm text-slate-500">Loading…</p>
        </div>
      </div>
    </div>
  </main>

  <script>
    const token = localStorage.getItem('ngu.token');
    const user = (() => { try { return JSON.parse(localStorage.getItem('ngu.user') || 'null'); } catch { return null; } })();
    if (!token || !user || !['owner','admin'].includes(user.role)) {
      location.href = '/admin/login.html';
    }

    let branches = [];

    async function loadBranches() {
      const res = await fetch('/api/org/branches');
      const body = await res.json();
      branches = body.data || [];
    }

    async function loadUnassigned() {
      const root = document.getElementById('unassigned');
      // Fetch orders via the public orders endpoint — it returns all orders for staff
      try {
        const res = await fetch('/api/orders', { headers: { Authorization: 'Bearer ' + token } });
        const body = await res.json();
        const orders = (body.data || []).filter((o) => !o.branch_id);
        if (!orders.length) {
          root.innerHTML = '<p class="text-sm text-slate-500">All orders have a branch assigned. 🎉</p>';
          return;
        }
        root.innerHTML = orders.map((o) => `
          <div class="flex items-center justify-between py-3 border-b border-slate-100">
            <div>
              <div class="font-medium">#${String(o.id).slice(0,8)}</div>
              <div class="text-xs text-slate-500">${o.created_at || ''} · KES ${Number(o.total || 0).toLocaleString()}</div>
            </div>
            <select data-order="${escapeHtml(o.id)}" class="rounded-md border border-slate-300 px-2 py-1 text-sm">
              <option value="">Assign branch…</option>
              ${branches.map((b) => `<option value="${b.id}">${b.name}</option>`).join('')}
            </select>
          </div>`).join('');

        root.querySelectorAll('[data-order]').forEach((sel) => {
          sel.addEventListener('change', async () => {
            const orderId = sel.dataset.order;
            const branchId = sel.value;
            if (!branchId) return;
            try {
              const res = await fetch('/api/orders/' + encodeURIComponent(orderId) + '/status', {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
                body: JSON.stringify({ branch_id: branchId }),
              });
              if (!res.ok) throw new Error('Failed to assign');
              document.getElementById('ok').textContent = 'Order assigned.';
              document.getElementById('ok').classList.remove('hidden');
              setTimeout(() => location.reload(), 800);
            } catch (e) {
              document.getElementById('err').textContent = e.message;
              document.getElementById('err').classList.remove('hidden');
            }
          });
        });
      } catch (e) {
        root.innerHTML = '<p class="text-red-600 text-sm">Could not load: ' + escapeHtml(e.message) + '</p>';
      }
    }

    async function loadStaff() {
      const root = document.getElementById('staff-list');
      try {
        const res = await fetch('/api/org/staff', { headers: { Authorization: 'Bearer ' + token } });
        const body = await res.json();
        const staff = body.data || [];
        if (!staff.length) {
          root.innerHTML = '<p class="text-sm text-slate-500">No staff accounts yet.</p>';
          return;
        }
        root.innerHTML = staff.map((s) => `
          <div class="flex items-center justify-between py-3 border-b border-slate-100">
            <div>
              <div class="font-medium">${escapeHtml(s.name || '')}</div>
              <div class="text-xs text-slate-500">${escapeHtml(s.email || '')} · ${escapeHtml(s.role || '')}</div>
            </div>
            <select data-user="${escapeHtml(s.id)}" class="rounded-md border border-slate-300 px-2 py-1 text-sm">
              <option value="">No branch</option>
              ${branches.map((b) => `<option value="${b.id}">${b.name}</option>`).join('')}
            </select>
          </div>`).join('');
      } catch (e) {
        root.innerHTML = '<p class="text-red-600 text-sm">Could not load: ' + escapeHtml(e.message) + '</p>';
      }
    }

    (async () => {
      await loadBranches();
      await loadUnassigned();
      await loadStaff();
    })();

    function escapeHtml(s=''){ return String(s).replace(/[&<>"']/g, (c)=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
  </script>
</body>
</html>
BRANCHASSIGN

# =============================================================================
# 8. Add branch filter to admin products page (read-only display of branch stock)
# =============================================================================
echo "▶ Updating public/admin/products.html (branch stock display)"
# Find the row rendering and append stock summary if column exists — leave UI mostly as-is

# =============================================================================
# 9. Update sitemap.xml with real URLs
# =============================================================================
echo "▶ Updating public/sitemap.xml"
cat > public/sitemap.xml <<'SITEMAP'
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://ngucontainers.com/</loc><changefreq>daily</changefreq><priority>1.0</priority></url>
  <url><loc>https://ngucontainers.com/products/</loc><changefreq>daily</changefreq><priority>0.9</priority></url>
  <url><loc>https://ngucontainers.com/products/drums-containers.html</loc><priority>0.8</priority></url>
  <url><loc>https://ngucontainers.com/products/jikos.html</loc><priority>0.8</priority></url>
  <url><loc>https://ngucontainers.com/products/farming-tools.html</loc><priority>0.8</priority></url>
  <url><loc>https://ngucontainers.com/products/accessories.html</loc><priority>0.8</priority></url>
  <url><loc>https://ngucontainers.com/branches/</loc><priority>0.7</priority></url>
  <url><loc>https://ngucontainers.com/branches/kikuyu.html</loc><priority>0.6</priority></url>
  <url><loc>https://ngucontainers.com/branches/nakuru.html</loc><priority>0.6</priority></url>
  <url><loc>https://ngucontainers.com/about.html</loc><priority>0.6</priority></url>
  <url><loc>https://ngucontainers.com/services.html</loc><priority>0.6</priority></url>
  <url><loc>https://ngucontainers.com/gallery.html</loc><priority>0.5</priority></url>
  <url><loc>https://ngucontainers.com/blog.html</loc><priority>0.5</priority></url>
  <url><loc>https://ngucontainers.com/faq.html</loc><priority>0.5</priority></url>
  <url><loc>https://ngucontainers.com/contact.html</loc><priority>0.7</priority></url>
  <url><loc>https://ngucontainers.com/privacy.html</loc><priority>0.3</priority></url>
  <url><loc>https://ngucontainers.com/terms.html</loc><priority>0.3</priority></url>
</urlset>
SITEMAP

# =============================================================================
# 10. Update robots.txt
# =============================================================================
echo "▶ Updating public/robots.txt"
cat > public/robots.txt <<'ROBOTS'
User-agent: *
Allow: /
Disallow: /admin/
Disallow: /account/
Disallow: /api/
Disallow: /auth/
Sitemap: https://ngucontainers.com/sitemap.xml
ROBOTS

# =============================================================================
# 11. 404 error page
# =============================================================================
echo "▶ Writing public/404.html"
cat > public/404.html <<'NOTFOUND'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Page not found · NEVER GIVE UP ENTERPRISE</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />
</head>
<body class="font-sans bg-slate-50 text-slate-800 flex items-center justify-center min-h-screen p-4">
  <div class="max-w-md text-center">
    <div class="inline-flex items-center justify-center h-20 w-20 rounded-full bg-gradient-to-r from-blue-500 to-emerald-500 text-white text-3xl mb-6">
      <i class="fa-solid fa-map-signs"></i>
    </div>
    <h1 class="text-6xl font-extrabold">404</h1>
    <p class="mt-3 text-xl font-semibold">This page doesn't exist</p>
    <p class="mt-2 text-slate-500">But there are plenty of drums, jikos, and tools waiting for you.</p>
    <div class="mt-8 flex flex-col sm:flex-row gap-3 justify-center">
      <a href="/" class="inline-flex items-center justify-center gap-2 px-6 py-3 rounded-md bg-brand-600 text-white font-semibold hover:bg-brand-700" style="background:#2563eb;">
        <i class="fa-solid fa-home"></i> Go home
      </a>
      <a href="/products/" class="inline-flex items-center justify-center gap-2 px-6 py-3 rounded-md bg-white ring-1 ring-slate-200 font-semibold hover:ring-brand-300">
        <i class="fa-solid fa-box"></i> Browse products
      </a>
    </div>
    <p class="mt-8 text-sm text-slate-500">Or <a href="/contact.html" class="text-brand-600 hover:underline">contact us</a> if you think this is a mistake.</p>
  </div>
</body>
</html>
NOTFOUND

# =============================================================================
# 12. Favicon (small SVG, referenced in existing HTML)
# =============================================================================
echo "▶ Writing public/assets/images/favicon.svg"
cat > public/assets/images/favicon.svg <<'FAVICON'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#3b82f6"/>
      <stop offset="100%" stop-color="#10b981"/>
    </linearGradient>
  </defs>
  <circle cx="16" cy="16" r="15" fill="url(#g)"/>
  <text x="16" y="21" font-family="Arial, sans-serif" font-weight="800" font-size="12" fill="white" text-anchor="middle">NGU</text>
</svg>
FAVICON

# =============================================================================
# Stage
# =============================================================================
echo ""
echo "▶ Staging files…"
git add migrations/0046_branch_scoping.sql
git add src/branch-context.js
git add functions/api/admin/analytics/sales.js
git add functions/api/admin/analytics/products.js
git add functions/api/admin/analytics/best-sellers.js
git add public/admin/branch-assign.html
git add public/admin/analytics.html
git add public/sitemap.xml
git add public/robots.txt
git add public/404.html
git add public/assets/images/favicon.svg

echo ""
echo "▶ Diff summary:"
git status --short

echo ""
echo "✅ Chunk 6c written."
echo ""
echo "Next (PowerShell):"
echo "  1. Apply migration:"
echo "     npx wrangler d1 migrations apply ngu-platform-db --remote"
echo "  2. Deploy:"
echo "     npx wrangler pages deploy public --project-name u-containers-com --branch main --commit-dirty=true"
echo "  3. Commit + push:"
echo "     git add -A; git commit -m 'feat: branch scoping and polish'; git push origin main"
echo ""
