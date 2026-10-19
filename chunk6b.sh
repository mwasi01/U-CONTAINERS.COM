#!/usr/bin/env bash
# chunk6b.sh — analytics dashboard with charts + best sellers
set -euo pipefail
cd "$(dirname "$0")"
echo "▶ Repo root: $(pwd)"

test -d public    || { echo "FATAL: public/ missing"; exit 1; }
test -d functions || { echo "FATAL: functions/ missing"; exit 1; }
mkdir -p functions/api/admin/analytics

# =============================================================================
# 1. functions/api/admin/analytics/sales.js — time series
# =============================================================================
echo "▶ Writing functions/api/admin/analytics/sales.js"
cat > functions/api/admin/analytics/sales.js <<'SALES'
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

// GET /api/admin/analytics/sales?period=day|week|month|year&from=YYYY-MM-DD&to=YYYY-MM-DD
export async function onRequestGet(ctx) {
  await requireEditor(ctx);
  const url = new URL(ctx.request.url);
  const period = url.searchParams.get('period') || 'day';

  const d = db(ctx.env);

  // SQLite date functions: strftime('%Y-%m-%d', created_at) for day,
  // %Y-%W for week, %Y-%m for month, %Y for year
  let groupExpr;
  switch (period) {
    case 'week':  groupExpr = "strftime('%Y-%W', created_at)"; break;
    case 'month': groupExpr = "strftime('%Y-%m', created_at)"; break;
    case 'year':  groupExpr = "strftime('%Y', created_at)";    break;
    default:      groupExpr = "strftime('%Y-%m-%d', created_at)"; break;
  }

  // Last N periods
  const limitMap = { day: 30, week: 12, month: 12, year: 5 };
  const limit = limitMap[period] || 30;

  const rows = await d.all(`
    SELECT
      ${groupExpr} AS label,
      COUNT(*) AS orders,
      COALESCE(SUM(total), 0) AS revenue
    FROM orders
    WHERE created_at IS NOT NULL
    GROUP BY label
    ORDER BY label DESC
    LIMIT ${limit}
  `);

  // Reverse to ascending (oldest first)
  const series = rows.reverse().map((r) => ({
    label: r.label || '',
    orders: Number(r.orders || 0),
    revenue: Number(r.revenue || 0),
  }));

  // Compute cost-based profit per period (join order_items with products)
  const profitRows = await d.all(`
    SELECT
      ${groupExpr.replace(/created_at/g, 'o.created_at')} AS label,
      COALESCE(SUM((oi.price - COALESCE(p.cost, 0)) * oi.qty), 0) AS profit
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.id
    LEFT JOIN products p ON p.id = oi.product_id
    WHERE o.created_at IS NOT NULL
    GROUP BY label
    ORDER BY label DESC
    LIMIT ${limit}
  `);

  const profitByLabel = {};
  for (const r of profitRows) profitByLabel[r.label] = Number(r.profit || 0);

  // Merge profit into series
  const withProfit = series.map((s) => ({ ...s, profit: profitByLabel[s.label] || 0 }));

  const totalRevenue = withProfit.reduce((sum, s) => sum + s.revenue, 0);
  const totalProfit = withProfit.reduce((sum, s) => sum + s.profit, 0);
  const totalOrders = withProfit.reduce((sum, s) => sum + s.orders, 0);
  const avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;

  return jsonResponse({
    period,
    series: withProfit,
    totals: { revenue: totalRevenue, profit: totalProfit, orders: totalOrders, avgOrderValue },
  });
}
SALES

# =============================================================================
# 2. functions/api/admin/analytics/products.js — top products + category pie
# =============================================================================
echo "▶ Writing functions/api/admin/analytics/products.js"
cat > functions/api/admin/analytics/products.js <<'PRODUCTS'
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
PRODUCTS

# =============================================================================
# 3. functions/api/admin/analytics/best-sellers.js — ranked by units and profit
# =============================================================================
echo "▶ Writing functions/api/admin/analytics/best-sellers.js"
cat > functions/api/admin/analytics/best-sellers.js <<'BEST'
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

// GET /api/admin/analytics/best-sellers
export async function onRequestGet(ctx) {
  await requireEditor(ctx);
  const d = db(ctx.env);

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
    LEFT JOIN products p ON p.id = oi.product_id
    GROUP BY oi.product_id, oi.name
  `;

  const byUnits = await d.all(baseSql + ' ORDER BY units_sold DESC LIMIT 20');
  const byProfit = await d.all(baseSql + ' ORDER BY profit DESC LIMIT 20');

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
    byUnits: byUnits.map(shape),
    byProfit: byProfit.map(shape),
  });
}
BEST

# =============================================================================
# 4. public/admin/analytics.html
# =============================================================================
echo "▶ Writing public/admin/analytics.html"
cat > public/admin/analytics.html <<'ANALYTICSHTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Analytics · Admin · NEVER GIVE UP ENTERPRISE</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
  <style>body{font-family:Inter,system-ui,sans-serif;}</style>
</head>
<body class="bg-slate-100 text-slate-800">

  <aside id="sidebar" class="fixed inset-y-0 left-0 w-64 bg-slate-900 text-slate-300 z-40 -translate-x-full lg:translate-x-0 transition-transform">
    <div class="p-6 flex items-center gap-3 border-b border-slate-800">
      <span class="h-10 w-10 rounded-full bg-gradient-to-r from-blue-500 to-emerald-500 text-white font-extrabold flex items-center justify-center text-sm">NGU</span>
      <div>
        <div class="text-sm font-extrabold text-white tracking-wide">NEVER GIVE UP</div>
        <div class="text-[11px] text-slate-500 tracking-widest">ADMIN</div>
      </div>
    </div>
    <nav class="mt-4 px-3 space-y-1 text-sm">
      <a href="/admin/" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-gauge w-4"></i> Dashboard</a>
      <a href="/admin/products.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-box w-4"></i> Products</a>
      <a href="/admin/analytics.html" class="flex items-center gap-3 px-3 py-2 rounded-md bg-slate-800 text-white"><i class="fa-solid fa-chart-line w-4"></i> Analytics</a>
      <a href="/admin/best-sellers.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-trophy w-4"></i> Best sellers</a>
      <a href="/account/orders.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-receipt w-4"></i> Orders</a>
      <a href="/admin/customers.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-users w-4"></i> Customers</a>
      <a href="/admin/messages.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-regular fa-envelope w-4"></i> Messages</a>
    </nav>
    <div class="absolute bottom-0 left-0 right-0 p-4 border-t border-slate-800">
      <div class="text-xs text-slate-500 mb-2">Signed in as</div>
      <div class="text-sm font-medium text-white truncate" id="user-email">—</div>
      <button id="logout" class="mt-3 w-full text-sm text-left text-red-400 hover:text-red-300 inline-flex items-center gap-2"><i class="fa-solid fa-arrow-right-from-bracket"></i> Sign out</button>
    </div>
  </aside>

  <header class="lg:hidden bg-white shadow-sm sticky top-0 z-30 flex items-center justify-between px-4 h-14">
    <button id="menu-btn" class="text-slate-700"><i class="fa-solid fa-bars"></i></button>
    <span class="text-sm font-bold">Analytics</span>
    <span class="w-6"></span>
  </header>

  <main class="lg:ml-64 min-h-screen p-6">
    <div class="max-w-6xl mx-auto">
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 class="text-3xl font-extrabold">Analytics</h1>
          <p class="text-slate-500 mt-1">Live sales performance · updated in real time</p>
        </div>
        <div class="flex gap-2">
          <select id="period" class="rounded-md border border-slate-300 px-3 py-2 text-sm">
            <option value="day">Last 30 days</option>
            <option value="week">Last 12 weeks</option>
            <option value="month">Last 12 months</option>
            <option value="year">Last 5 years</option>
          </select>
        </div>
      </div>

      <div id="stats" class="mt-8 grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div class="bg-white rounded-xl ring-1 ring-slate-100 p-5">
          <div class="text-xs uppercase tracking-widest text-slate-500">Revenue (KES)</div>
          <div class="mt-2 text-3xl font-extrabold text-brand-600" id="stat-revenue" style="color:#2563eb;">—</div>
        </div>
        <div class="bg-white rounded-xl ring-1 ring-slate-100 p-5">
          <div class="text-xs uppercase tracking-widest text-slate-500">Profit (KES)</div>
          <div class="mt-2 text-3xl font-extrabold text-emerald-600" id="stat-profit">—</div>
        </div>
        <div class="bg-white rounded-xl ring-1 ring-slate-100 p-5">
          <div class="text-xs uppercase tracking-widest text-slate-500">Orders</div>
          <div class="mt-2 text-3xl font-extrabold" id="stat-orders">—</div>
        </div>
        <div class="bg-white rounded-xl ring-1 ring-slate-100 p-5">
          <div class="text-xs uppercase tracking-widest text-slate-500">Avg order value</div>
          <div class="mt-2 text-3xl font-extrabold" id="stat-aov">—</div>
        </div>
      </div>

      <div class="mt-6 bg-white rounded-2xl ring-1 ring-slate-100 p-6">
        <h2 class="text-lg font-bold">Revenue &amp; profit over time</h2>
        <div class="mt-4 h-80"><canvas id="chart-time"></canvas></div>
      </div>

      <div class="mt-6 grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div class="bg-white rounded-2xl ring-1 ring-slate-100 p-6">
          <h2 class="text-lg font-bold">Top 10 products by units sold</h2>
          <div class="mt-4 h-80"><canvas id="chart-top"></canvas></div>
        </div>
        <div class="bg-white rounded-2xl ring-1 ring-slate-100 p-6">
          <h2 class="text-lg font-bold">Revenue by category</h2>
          <div class="mt-4 h-80"><canvas id="chart-pie"></canvas></div>
        </div>
      </div>
    </div>
  </main>

  <script>
    const token = localStorage.getItem('ngu.token');
    const user = (() => { try { return JSON.parse(localStorage.getItem('ngu.user') || 'null'); } catch { return null; } })();
    if (!token || !user || !['owner','admin','manager'].includes(user.role)) {
      location.href = '/admin/login.html';
    }
    document.getElementById('user-email').textContent = user?.email || '—';
    document.getElementById('menu-btn')?.addEventListener('click', () => document.getElementById('sidebar').classList.toggle('-translate-x-full'));
    document.getElementById('logout').addEventListener('click', () => {
      localStorage.removeItem('ngu.token'); localStorage.removeItem('ngu.user');
      location.href = '/admin/login.html';
    });

    const currency = (n) => 'KES ' + Number(n || 0).toLocaleString('en-KE', { maximumFractionDigits: 0 });

    let chartTime, chartTop, chartPie;

    async function loadSales(period) {
      const res = await fetch('/api/admin/analytics/sales?period=' + period, {
        headers: { Authorization: 'Bearer ' + token },
      });
      const body = await res.json();
      if (!res.ok || body.error) throw new Error(body.error?.message || 'Sales load failed');
      return body.data;
    }

    async function loadProducts() {
      const res = await fetch('/api/admin/analytics/products', {
        headers: { Authorization: 'Bearer ' + token },
      });
      const body = await res.json();
      if (!res.ok || body.error) throw new Error(body.error?.message || 'Products load failed');
      return body.data;
    }

    function renderStats(totals) {
      document.getElementById('stat-revenue').textContent = currency(totals.revenue);
      document.getElementById('stat-profit').textContent = currency(totals.profit);
      document.getElementById('stat-orders').textContent = Number(totals.orders || 0).toLocaleString();
      document.getElementById('stat-aov').textContent = currency(totals.avgOrderValue);
    }

    function renderTimeChart(series) {
      const labels = series.map((s) => s.label);
      const revenue = series.map((s) => s.revenue);
      const profit = series.map((s) => s.profit);

      if (chartTime) chartTime.destroy();
      const ctx = document.getElementById('chart-time').getContext('2d');
      chartTime = new Chart(ctx, {
        type: 'line',
        data: {
          labels,
          datasets: [
            {
              label: 'Revenue',
              data: revenue,
              borderColor: '#2563eb',
              backgroundColor: 'rgba(37, 99, 235, 0.1)',
              tension: 0.3,
              fill: true,
              borderWidth: 2,
              pointRadius: 3,
            },
            {
              label: 'Profit',
              data: profit,
              borderColor: '#10b981',
              backgroundColor: 'rgba(16, 185, 129, 0.1)',
              tension: 0.3,
              fill: true,
              borderWidth: 2,
              pointRadius: 3,
            },
          ],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { position: 'top' } },
          scales: { y: { beginAtZero: true, ticks: { callback: (v) => 'KES ' + Number(v).toLocaleString() } } },
        },
      });
    }

    function renderTopChart(topProducts) {
      const labels = topProducts.map((p) => p.name.length > 24 ? p.name.slice(0, 24) + '…' : p.name);
      const data = topProducts.map((p) => p.unitsSold);

      if (chartTop) chartTop.destroy();
      const ctx = document.getElementById('chart-top').getContext('2d');
      chartTop = new Chart(ctx, {
        type: 'bar',
        data: {
          labels,
          datasets: [{
            label: 'Units sold',
            data,
            backgroundColor: '#3b82f6',
            borderRadius: 4,
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          indexAxis: 'y',
          plugins: { legend: { display: false } },
          scales: { x: { beginAtZero: true, ticks: { stepSize: 1 } } },
        },
      });
    }

    function renderPieChart(breakdown) {
      const labels = breakdown.map((c) => c.category);
      const data = breakdown.map((c) => c.revenue);
      const palette = ['#2563eb', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#06b6d4'];

      if (chartPie) chartPie.destroy();
      const ctx = document.getElementById('chart-pie').getContext('2d');
      chartPie = new Chart(ctx, {
        type: 'doughnut',
        data: {
          labels,
          datasets: [{
            data,
            backgroundColor: palette.slice(0, labels.length),
            borderWidth: 2,
            borderColor: '#ffffff',
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: { position: 'bottom' },
            tooltip: {
              callbacks: {
                label: (ctx) => ctx.label + ': ' + currency(ctx.raw),
              },
            },
          },
        },
      });
    }

    async function refresh() {
      const period = document.getElementById('period').value;
      try {
        const [sales, products] = await Promise.all([loadSales(period), loadProducts()]);
        renderStats(sales.totals);
        renderTimeChart(sales.series);
        renderTopChart(products.topProducts);
        renderPieChart(products.categoryBreakdown);
      } catch (e) {
        document.getElementById('stat-revenue').textContent = 'Error';
        console.error(e);
      }
    }

    document.getElementById('period').addEventListener('change', refresh);
    refresh();
  </script>
</body>
</html>
ANALYTICSHTML

# =============================================================================
# 5. public/admin/best-sellers.html
# =============================================================================
echo "▶ Writing public/admin/best-sellers.html"
cat > public/admin/best-sellers.html <<'BESTHTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Best sellers · Admin · NEVER GIVE UP ENTERPRISE</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />
  <style>body{font-family:Inter,system-ui,sans-serif;}</style>
</head>
<body class="bg-slate-100 text-slate-800">

  <aside id="sidebar" class="fixed inset-y-0 left-0 w-64 bg-slate-900 text-slate-300 z-40 -translate-x-full lg:translate-x-0 transition-transform">
    <div class="p-6 flex items-center gap-3 border-b border-slate-800">
      <span class="h-10 w-10 rounded-full bg-gradient-to-r from-blue-500 to-emerald-500 text-white font-extrabold flex items-center justify-center text-sm">NGU</span>
      <div><div class="text-sm font-extrabold text-white tracking-wide">NEVER GIVE UP</div><div class="text-[11px] text-slate-500 tracking-widest">ADMIN</div></div>
    </div>
    <nav class="mt-4 px-3 space-y-1 text-sm">
      <a href="/admin/" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-gauge w-4"></i> Dashboard</a>
      <a href="/admin/products.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-box w-4"></i> Products</a>
      <a href="/admin/analytics.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-chart-line w-4"></i> Analytics</a>
      <a href="/admin/best-sellers.html" class="flex items-center gap-3 px-3 py-2 rounded-md bg-slate-800 text-white"><i class="fa-solid fa-trophy w-4"></i> Best sellers</a>
      <a href="/account/orders.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-receipt w-4"></i> Orders</a>
    </nav>
    <div class="absolute bottom-0 left-0 right-0 p-4 border-t border-slate-800">
      <div class="text-xs text-slate-500 mb-2">Signed in as</div>
      <div class="text-sm font-medium text-white truncate" id="user-email">—</div>
      <button id="logout" class="mt-3 w-full text-sm text-left text-red-400 hover:text-red-300 inline-flex items-center gap-2"><i class="fa-solid fa-arrow-right-from-bracket"></i> Sign out</button>
    </div>
  </aside>

  <header class="lg:hidden bg-white shadow-sm sticky top-0 z-30 flex items-center justify-between px-4 h-14">
    <button id="menu-btn" class="text-slate-700"><i class="fa-solid fa-bars"></i></button>
    <span class="text-sm font-bold">Best sellers</span>
    <span class="w-6"></span>
  </header>

  <main class="lg:ml-64 min-h-screen p-6">
    <div class="max-w-6xl mx-auto">
      <h1 class="text-3xl font-extrabold">Best sellers</h1>
      <p class="text-slate-500 mt-1">Your top performing products by units sold and by profit.</p>

      <div class="mt-8 grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div class="bg-white rounded-2xl ring-1 ring-slate-100 p-6">
          <div class="flex items-center gap-2 mb-4">
            <i class="fa-solid fa-fire text-orange-500"></i>
            <h2 class="text-lg font-bold">By units sold</h2>
          </div>
          <div id="by-units"><p class="text-sm text-slate-500">Loading…</p></div>
        </div>

        <div class="bg-white rounded-2xl ring-1 ring-slate-100 p-6">
          <div class="flex items-center gap-2 mb-4">
            <i class="fa-solid fa-sack-dollar text-emerald-600"></i>
            <h2 class="text-lg font-bold">By profit (KES)</h2>
          </div>
          <div id="by-profit"><p class="text-sm text-slate-500">Loading…</p></div>
        </div>
      </div>
    </div>
  </main>

  <script>
    const token = localStorage.getItem('ngu.token');
    const user = (() => { try { return JSON.parse(localStorage.getItem('ngu.user') || 'null'); } catch { return null; } })();
    if (!token || !user || !['owner','admin','manager'].includes(user.role)) location.href = '/admin/login.html';
    document.getElementById('user-email').textContent = user?.email || '—';
    document.getElementById('menu-btn')?.addEventListener('click', () => document.getElementById('sidebar').classList.toggle('-translate-x-full'));
    document.getElementById('logout').addEventListener('click', () => {
      localStorage.removeItem('ngu.token'); localStorage.removeItem('ngu.user');
      location.href = '/admin/login.html';
    });

    const currency = (n) => 'KES ' + Number(n || 0).toLocaleString('en-KE', { maximumFractionDigits: 0 });

    function renderList(rootId, rows, valueKey) {
      const root = document.getElementById(rootId);
      if (!rows.length) {
        root.innerHTML = '<p class="text-sm text-slate-500">No sales data yet. Once orders come in, they appear here.</p>';
        return;
      }
      const max = Math.max(...rows.map((r) => r[valueKey]));
      root.innerHTML = '<div class="space-y-2">' + rows.map((r, i) => {
        const pct = max > 0 ? Math.round((r[valueKey] / max) * 100) : 0;
        return `
          <div class="flex items-center gap-3">
            <span class="text-xs font-bold w-6 text-slate-400">#${i + 1}</span>
            <div class="flex-1 min-w-0">
              <div class="flex justify-between text-sm">
                <span class="font-medium truncate">${escapeHtml(r.name)}</span>
                <span class="font-semibold whitespace-nowrap">${valueKey === 'unitsSold' ? r.unitsSold + ' units' : currency(r.profit)}</span>
              </div>
              <div class="mt-1 h-1.5 rounded-full bg-slate-100 overflow-hidden">
                <div class="h-full rounded-full ${valueKey === 'unitsSold' ? 'bg-orange-500' : 'bg-emerald-500'}" style="width:${pct}%"></div>
              </div>
              <div class="text-xs text-slate-500 mt-1">
                ${currency(r.revenue)} revenue · ${currency(r.profit)} profit · ${r.marginPct}% margin
              </div>
            </div>
          </div>`;
      }).join('') + '</div>';
    }

    async function load() {
      try {
        const res = await fetch('/api/admin/analytics/best-sellers', {
          headers: { Authorization: 'Bearer ' + token },
        });
        const body = await res.json();
        if (!res.ok || body.error) throw new Error(body.error?.message || 'Load failed');
        renderList('by-units', body.data.byUnits, 'unitsSold');
        renderList('by-profit', body.data.byProfit, 'profit');
      } catch (e) {
        document.getElementById('by-units').innerHTML = '<p class="text-red-600 text-sm">' + escapeHtml(e.message) + '</p>';
        document.getElementById('by-profit').innerHTML = '<p class="text-red-600 text-sm">' + escapeHtml(e.message) + '</p>';
      }
    }

    function escapeHtml(s=''){ return String(s).replace(/[&<>"']/g, (c)=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
    load();
  </script>
</body>
</html>
BESTHTML

# =============================================================================
# 6. Stage
# =============================================================================
echo ""
echo "▶ Staging files…"
git add functions/api/admin/analytics/sales.js
git add functions/api/admin/analytics/products.js
git add functions/api/admin/analytics/best-sellers.js
git add public/admin/analytics.html
git add public/admin/best-sellers.html

echo ""
echo "▶ Diff summary:"
git status --short

echo ""
echo "✅ Chunk 6b written."
echo ""
echo "Next (PowerShell):"
echo "  cd C:\\Users\\hp\\Desktop\\repo-tmp"
echo "  npx wrangler pages deploy public --project-name u-containers-com --branch main --commit-dirty=true"
echo "  git add -A; git commit -m 'feat: analytics dashboard with charts'; git push origin main"
echo ""
