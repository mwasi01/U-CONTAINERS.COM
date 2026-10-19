#!/usr/bin/env bash
# chunk5.sh — admin login, admin dashboard, admin middleware
set -euo pipefail
cd "$(dirname "$0")"
echo "▶ Repo root: $(pwd)"

test -d public || { echo "FATAL: public/ missing"; exit 1; }
test -d functions || { echo "FATAL: functions/ missing"; exit 1; }
mkdir -p public/admin public/admin/assets/js

# =============================================================================
# 1. functions/admin/_middleware.js — role gate
# =============================================================================
echo "▶ Writing functions/admin/_middleware.js"
cat > functions/admin/_middleware.js <<'ADMINMW'
export async function onRequest(ctx) {
  const url = new URL(ctx.request.url);
  // Allow the login page itself (it's a static file — middleware only runs for /functions)
  // If we get here, it means a /api/admin/* call or dynamic route.

  const user = ctx.data?.user;
  if (!user) {
    return new Response(JSON.stringify({ data: null, error: { code: 'unauthorized', message: 'Sign in required' } }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  if (!['owner', 'admin', 'manager'].includes(user.role)) {
    return new Response(JSON.stringify({ data: null, error: { code: 'forbidden', message: 'Admin access only' } }), {
      status: 403,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  return ctx.next();
}
ADMINMW

# =============================================================================
# 2. functions/api/admin/stats.js — dashboard aggregate stats
# =============================================================================
echo "▶ Writing functions/api/admin/stats.js"
mkdir -p functions/api/admin
cat > functions/api/admin/stats.js <<'STATS'
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
STATS

# =============================================================================
# 3. public/admin/login.html
# =============================================================================
echo "▶ Writing public/admin/login.html"
cat > public/admin/login.html <<'LOGIN'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Admin sign in · NEVER GIVE UP ENTERPRISE</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />
</head>
<body class="font-sans bg-slate-900 text-slate-800 flex items-center justify-center min-h-screen p-4">
  <div class="w-full max-w-md bg-white rounded-2xl shadow-2xl p-8">
    <div class="text-center">
      <div class="inline-flex items-center gap-3">
        <span class="h-12 w-12 rounded-full bg-gradient-to-r from-blue-500 to-emerald-500 text-white font-extrabold flex items-center justify-center">NGU</span>
        <div class="text-left">
          <div class="text-sm font-extrabold tracking-wide">NEVER GIVE UP</div>
          <div class="text-[11px] text-slate-500 tracking-widest">ENTERPRISE · ADMIN</div>
        </div>
      </div>
      <h1 class="mt-6 text-2xl font-extrabold">Admin sign in</h1>
      <p class="mt-1 text-sm text-slate-500">Owner, admin or manager accounts only.</p>
    </div>
    <div id="err" class="hidden mt-4 p-3 rounded-md bg-red-50 border border-red-200 text-red-700 text-sm"></div>
    <form id="login-form" class="mt-6 space-y-4">
      <div>
        <label class="text-sm font-medium">Email</label>
        <input name="email" type="email" required autocomplete="email" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500" />
      </div>
      <div>
        <label class="text-sm font-medium">Password</label>
        <input name="password" type="password" required autocomplete="current-password" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500" />
      </div>
      <button type="submit" class="w-full inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-md bg-slate-900 text-white font-semibold hover:bg-slate-800">
        <i class="fa-solid fa-arrow-right-to-bracket"></i> Sign in
      </button>
    </form>
    <div class="mt-6 text-center text-sm text-slate-500">
      <a href="/" class="hover:text-slate-800">← Back to storefront</a>
    </div>
  </div>
  <script type="module">
    const form = document.getElementById('login-form');
    const err = document.getElementById('err');
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      err.classList.add('hidden');
      const data = Object.fromEntries(new FormData(form));
      try {
        const res = await fetch('/api/auth/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(data),
        });
        const body = await res.json();
        if (!res.ok || body.error) throw new Error(body.error?.message || 'Invalid credentials');

        const user = body.data.user;
        if (!['owner','admin','manager'].includes(user.role)) {
          throw new Error('This account is not an admin. Ask the owner for access.');
        }

        localStorage.setItem('ngu.token', body.data.token);
        localStorage.setItem('ngu.user', JSON.stringify(user));
        location.href = '/admin/';
      } catch (e) {
        err.textContent = e.message;
        err.classList.remove('hidden');
      }
    });
  </script>
</body>
</html>
LOGIN

# =============================================================================
# 4. public/admin/index.html — dashboard
# =============================================================================
echo "▶ Writing public/admin/index.html"
cat > public/admin/index.html <<'DASH'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Admin dashboard · NEVER GIVE UP ENTERPRISE</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />
  <style>body{font-family:Inter,system-ui,sans-serif;}</style>
</head>
<body class="bg-slate-100 text-slate-800">

  <!-- Sidebar -->
  <aside id="sidebar" class="fixed inset-y-0 left-0 w-64 bg-slate-900 text-slate-300 z-40 -translate-x-full lg:translate-x-0 transition-transform">
    <div class="p-6 flex items-center gap-3 border-b border-slate-800">
      <span class="h-10 w-10 rounded-full bg-gradient-to-r from-blue-500 to-emerald-500 text-white font-extrabold flex items-center justify-center text-sm">NGU</span>
      <div>
        <div class="text-sm font-extrabold text-white tracking-wide">NEVER GIVE UP</div>
        <div class="text-[11px] text-slate-500 tracking-widest">ADMIN</div>
      </div>
    </div>
    <nav class="mt-4 px-3 space-y-1 text-sm">
      <a href="/admin/" class="flex items-center gap-3 px-3 py-2 rounded-md bg-slate-800 text-white"><i class="fa-solid fa-gauge w-4"></i> Dashboard</a>
      <a href="/products/" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-box w-4"></i> Products</a>
      <a href="/account/orders.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-receipt w-4"></i> Orders</a>
      <a href="/admin/customers.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-users w-4"></i> Customers</a>
      <a href="/admin/messages.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-regular fa-envelope w-4"></i> Messages</a>
      <a href="/admin/branches.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-location-dot w-4"></i> Branches</a>
    </nav>
    <div class="absolute bottom-0 left-0 right-0 p-4 border-t border-slate-800">
      <div class="text-xs text-slate-500 mb-2">Signed in as</div>
      <div class="text-sm font-medium text-white truncate" id="user-email">—</div>
      <button id="logout" class="mt-3 w-full text-sm text-left text-red-400 hover:text-red-300 inline-flex items-center gap-2">
        <i class="fa-solid fa-arrow-right-from-bracket"></i> Sign out
      </button>
    </div>
  </aside>

  <!-- Mobile header -->
  <header class="lg:hidden bg-white shadow-sm sticky top-0 z-30 flex items-center justify-between px-4 h-14">
    <button id="menu-btn" class="text-slate-700"><i class="fa-solid fa-bars"></i></button>
    <span class="text-sm font-bold">Admin</span>
    <span class="w-6"></span>
  </header>

  <!-- Main -->
  <main class="lg:ml-64 min-h-screen p-6">
    <div class="max-w-6xl mx-auto">
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 class="text-3xl font-extrabold">Dashboard</h1>
          <p class="text-slate-500 mt-1" id="sub">Loading…</p>
        </div>
        <a href="/" target="_blank" class="inline-flex items-center gap-2 px-4 py-2 rounded-md bg-white ring-1 ring-slate-200 text-sm font-medium hover:ring-slate-300">
          <i class="fa-solid fa-arrow-up-right-from-square"></i> View storefront
        </a>
      </div>

      <!-- Stats grid -->
      <div id="stats" class="mt-8 grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div class="bg-white rounded-xl ring-1 ring-slate-100 p-5">
          <div class="text-xs uppercase tracking-widest text-slate-500">Products</div>
          <div class="mt-2 text-3xl font-extrabold" id="stat-products">—</div>
        </div>
        <div class="bg-white rounded-xl ring-1 ring-slate-100 p-5">
          <div class="text-xs uppercase tracking-widest text-slate-500">Orders</div>
          <div class="mt-2 text-3xl font-extrabold" id="stat-orders">—</div>
        </div>
        <div class="bg-white rounded-xl ring-1 ring-slate-100 p-5">
          <div class="text-xs uppercase tracking-widest text-slate-500">Revenue (KES)</div>
          <div class="mt-2 text-3xl font-extrabold" id="stat-revenue">—</div>
        </div>
        <div class="bg-white rounded-xl ring-1 ring-slate-100 p-5">
          <div class="text-xs uppercase tracking-widest text-slate-500">Customers</div>
          <div class="mt-2 text-3xl font-extrabold" id="stat-users">—</div>
        </div>
      </div>

      <div class="mt-6 grid grid-cols-2 gap-4">
        <div class="bg-white rounded-xl ring-1 ring-slate-100 p-5 flex items-center justify-between">
          <div>
            <div class="text-xs uppercase tracking-widest text-slate-500">New messages</div>
            <div class="mt-2 text-2xl font-extrabold" id="stat-messages">—</div>
          </div>
          <i class="fa-regular fa-envelope text-3xl text-blue-500"></i>
        </div>
        <div class="bg-white rounded-xl ring-1 ring-slate-100 p-5 flex items-center justify-between">
          <div>
            <div class="text-xs uppercase tracking-widest text-slate-500">Branches</div>
            <div class="mt-2 text-2xl font-extrabold" id="stat-branches">—</div>
          </div>
          <i class="fa-solid fa-location-dot text-3xl text-emerald-500"></i>
        </div>
      </div>

      <!-- Recent orders -->
      <div class="mt-8 bg-white rounded-2xl ring-1 ring-slate-100 p-6">
        <h2 class="text-lg font-bold">Recent orders</h2>
        <div id="orders-list" class="mt-4"><p class="text-sm text-slate-500">Loading…</p></div>
      </div>

      <!-- Recent messages -->
      <div class="mt-6 bg-white rounded-2xl ring-1 ring-slate-100 p-6">
        <h2 class="text-lg font-bold">Recent contact messages</h2>
        <div id="messages-list" class="mt-4"><p class="text-sm text-slate-500">Loading…</p></div>
      </div>
    </div>
  </main>

  <script>
    // Auth guard: must be logged in with admin role
    const token = localStorage.getItem('ngu.token');
    const user = (() => { try { return JSON.parse(localStorage.getItem('ngu.user') || 'null'); } catch { return null; } })();
    if (!token || !user || !['owner','admin','manager'].includes(user.role)) {
      location.href = '/admin/login.html';
    }
    document.getElementById('user-email').textContent = user?.email || '—';

    // Sidebar toggle
    document.getElementById('menu-btn')?.addEventListener('click', () => {
      document.getElementById('sidebar').classList.toggle('-translate-x-full');
    });

    // Logout
    document.getElementById('logout').addEventListener('click', async () => {
      try {
        await fetch('/api/auth/logout', { method: 'POST', headers: { Authorization: 'Bearer ' + token } });
      } catch {}
      localStorage.removeItem('ngu.token');
      localStorage.removeItem('ngu.user');
      location.href = '/admin/login.html';
    });

    // Load dashboard data
    (async () => {
      try {
        const res = await fetch('/api/admin/stats', { headers: { Authorization: 'Bearer ' + token } });
        const body = await res.json();
        if (!res.ok || body.error) throw new Error(body.error?.message || 'Could not load stats');
        const { stats, recentOrders, recentMessages } = body.data;

        document.getElementById('sub').textContent = 'Live stats for NEVER GIVE UP ENTERPRISE';
        document.getElementById('stat-products').textContent = stats.products;
        document.getElementById('stat-orders').textContent = stats.orders;
        document.getElementById('stat-revenue').textContent = Number(stats.revenue).toLocaleString();
        document.getElementById('stat-users').textContent = stats.users;
        document.getElementById('stat-messages').textContent = stats.newMessages;
        document.getElementById('stat-branches').textContent = stats.branches;

        const ordersRoot = document.getElementById('orders-list');
        if (!recentOrders.length) {
          ordersRoot.innerHTML = '<p class="text-sm text-slate-500">No orders yet.</p>';
        } else {
          ordersRoot.innerHTML = '<div class="divide-y divide-slate-100">' + recentOrders.map((o) => `
            <div class="flex items-center justify-between py-3">
              <div>
                <div class="font-medium">Order #${String(o.id).slice(0, 8)}</div>
                <div class="text-xs text-slate-500">${o.created_at || ''}</div>
              </div>
              <div class="text-right">
                <div class="font-semibold">KES ${Number(o.total || 0).toLocaleString()}</div>
                <span class="text-xs px-2 py-0.5 rounded-full ${o.status === 'pending' ? 'bg-yellow-100 text-yellow-800' : 'bg-emerald-100 text-emerald-800'}">${o.status || 'pending'}</span>
              </div>
            </div>`).join('') + '</div>';
        }

        const msgsRoot = document.getElementById('messages-list');
        if (!recentMessages.length) {
          msgsRoot.innerHTML = '<p class="text-sm text-slate-500">No messages yet.</p>';
        } else {
          msgsRoot.innerHTML = '<div class="divide-y divide-slate-100">' + recentMessages.map((m) => `
            <div class="py-3">
              <div class="flex justify-between">
                <div class="font-medium">${escapeHtml(m.name || '')} <span class="text-xs text-slate-500">&lt;${escapeHtml(m.email || '')}&gt;</span></div>
                <div class="text-xs text-slate-500">${m.created_at || ''}</div>
              </div>
              <div class="text-sm text-slate-600 mt-1">${escapeHtml(m.subject || '')}</div>
            </div>`).join('') + '</div>';
        }
      } catch (e) {
        document.getElementById('sub').textContent = 'Error: ' + e.message;
      }
    })();

    function escapeHtml(s=''){return String(s).replace(/[&<>"']/g, (c)=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
  </script>
</body>
</html>
DASH

# =============================================================================
# 5. Stub admin sub-pages (customers, messages, branches) — branded
# =============================================================================
write_admin_page() {
  local path="$1"
  local title="$2"
  local body="$3"
  cat > "public/admin/$path" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${title} · Admin · NEVER GIVE UP ENTERPRISE</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />
</head>
<body class="font-sans bg-slate-100 text-slate-800 min-h-screen">
  <header class="bg-slate-900 text-white px-6 h-14 flex items-center justify-between">
    <a href="/admin/" class="flex items-center gap-2 text-sm font-bold">
      <i class="fa-solid fa-arrow-left"></i> Back to dashboard
    </a>
    <span class="text-sm">${title}</span>
  </header>
  <main class="max-w-4xl mx-auto p-6">
    <h1 class="text-2xl font-extrabold">${title}</h1>
    <div class="mt-6 bg-white rounded-2xl ring-1 ring-slate-100 p-8 text-center text-slate-500">
      ${body}
    </div>
  </main>
</body>
</html>
EOF
}

echo "▶ Writing admin sub-pages"
write_admin_page "customers.html" "Customers" '<i class="fa-solid fa-users text-4xl text-slate-300"></i><p class="mt-4 font-semibold text-slate-700">Coming soon</p><p class="mt-1 text-sm">Customer management will be added in a future update.</p>'
write_admin_page "messages.html" "Messages" '<i class="fa-regular fa-envelope text-4xl text-slate-300"></i><p class="mt-4 font-semibold text-slate-700">Coming soon</p><p class="mt-1 text-sm">Inbox with full message threads will be added in a future update.</p>'
write_admin_page "branches.html" "Branches" '<i class="fa-solid fa-location-dot text-4xl text-slate-300"></i><p class="mt-4 font-semibold text-slate-700">Coming soon</p><p class="mt-1 text-sm">Branch management will be added in a future update.</p>'

# =============================================================================
# 6. Stage
# =============================================================================
echo ""
echo "▶ Staging files…"
git add functions/admin/_middleware.js functions/api/admin/stats.js public/admin/

echo ""
echo "▶ Diff summary:"
git status --short

echo ""
echo "✅ Chunk 5 written."
echo ""
echo "Next (PowerShell):"
echo "  cd C:\\Users\\hp\\Desktop\\repo-tmp"
echo "  npx wrangler pages deploy public --project-name u-containers-com --branch main --commit-dirty=true"
echo "  git add -A; git commit -m 'feat: admin dashboard'; git push origin main"
echo ""
