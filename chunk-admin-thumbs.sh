#!/usr/bin/env bash
# chunk-admin-thumbs.sh — add product thumbnails to admin products table
set -euo pipefail
cd "$(dirname "$0")"
echo "▶ Repo root: $(pwd)"

test -f public/admin/products.html || { echo "FATAL: public/admin/products.html missing"; exit 1; }

# =============================================================================
# Rewrite public/admin/products.html — with thumbnail column
# =============================================================================
echo "▶ Rewriting public/admin/products.html with thumbnails"
cat > public/admin/products.html <<'PRODUCTSHTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Products · Admin · NEVER GIVE UP ENTERPRISE</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />
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
      <a href="/admin/products.html" class="flex items-center gap-3 px-3 py-2 rounded-md bg-slate-800 text-white"><i class="fa-solid fa-box w-4"></i> Products</a>
      <a href="/admin/analytics.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-chart-line w-4"></i> Analytics</a>
      <a href="/admin/best-sellers.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-trophy w-4"></i> Best sellers</a>
      <a href="/admin/branch-assign.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-code-branch w-4"></i> Branch assign</a>
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
    <span class="text-sm font-bold">Products</span>
    <span class="w-6"></span>
  </header>

  <main class="lg:ml-64 min-h-screen p-6">
    <div class="max-w-7xl mx-auto">
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 class="text-3xl font-extrabold">Products</h1>
          <p class="text-slate-500 mt-1">Manage your catalog, prices, costs, and photos.</p>
        </div>
        <a href="/admin/product-new.html" class="inline-flex items-center gap-2 px-5 py-2.5 rounded-md bg-blue-600 text-white font-semibold hover:bg-blue-700">
          <i class="fa-solid fa-plus"></i> Add product
        </a>
      </div>

      <div class="mt-6 flex flex-col sm:flex-row gap-3">
        <input id="search" placeholder="Search products…" class="flex-1 rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500" />
        <select id="category-filter" class="rounded-md border border-slate-300 px-3 py-2">
          <option value="">All categories</option>
          <option value="drums-containers">Drums & Containers</option>
          <option value="jikos">Jikos</option>
          <option value="farming-tools">Farming Tools</option>
          <option value="accessories">Accessories</option>
        </select>
      </div>

      <div class="mt-6 bg-white rounded-2xl ring-1 ring-slate-100 overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead class="bg-slate-50 text-slate-600 text-xs uppercase tracking-wider">
              <tr>
                <th class="text-left p-4 w-16">Photo</th>
                <th class="text-left p-4">Product</th>
                <th class="text-left p-4">Category</th>
                <th class="text-right p-4">Price (KES)</th>
                <th class="text-right p-4">Cost (KES)</th>
                <th class="text-right p-4">Profit/unit</th>
                <th class="text-center p-4">Stock</th>
                <th class="text-right p-4">Actions</th>
              </tr>
            </thead>
            <tbody id="tbody"><tr><td colspan="8" class="p-6 text-center text-slate-500">Loading…</td></tr></tbody>
          </table>
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

    let products = [];

    // Map product IDs to bundled product photos — same as the storefront
    const BUNDLED_IMAGES = {
      'p_250l_open':   '/assets/images/products/250ltrs open.jpg',
      'p_250l_closed': '/assets/images/products/250ltrs.jpg',
      'p_170l_funiko': '/assets/images/products/170ltrs.jpg',
      'p_120l':        '/assets/images/products/120ltrs.jpg',
      'p_small_jiko':  '/assets/images/products/small jiko.jpg',
      'p_std_jiko':    '/assets/images/products/stardand jiko.jpg',
      'p_med_jiko':    '/assets/images/products/mediumsized jiko.jpg',
      'p_size13_jiko': '/assets/images/products/size13jiko.jpg',
      'p_vifuniko':    '/assets/images/products/vifuniko.jpg',
      'p_metal_drum':  '/assets/images/products/metallic drum.jpg',
      // Farming tools — no bundled photo, use placeholder
      'p_spade':       null,
      'p_rake_sm':     null,
      'p_rake_big':    null,
      'p_fork_jembe':  null,
    };

    function productThumb(p) {
      if (p.image) return p.image;
      const mapped = BUNDLED_IMAGES[p.id] || BUNDLED_IMAGES[p.slug];
      return mapped || '/assets/images/placeholder.svg';
    }

    async function load() {
      const q = document.getElementById('search').value.trim();
      const cat = document.getElementById('category-filter').value;
      const params = new URLSearchParams();
      if (q) params.set('q', q);
      if (cat) params.set('category', cat);
      const url = '/api/admin/products' + (params.toString() ? '?' + params.toString() : '');
      const res = await fetch(url, { headers: { Authorization: 'Bearer ' + token } });
      const body = await res.json();
      if (!res.ok) { document.getElementById('tbody').innerHTML = '<tr><td colspan="8" class="p-6 text-center text-red-600">' + (body.error?.message || 'Failed') + '</td></tr>'; return; }
      products = body.data || [];
      renderTable();
    }

    function renderTable() {
      const tbody = document.getElementById('tbody');
      if (!products.length) {
        tbody.innerHTML = '<tr><td colspan="8" class="p-6 text-center text-slate-500">No products. <a href="/admin/product-new.html" class="text-blue-600 hover:underline">Add one →</a></td></tr>';
        return;
      }
      tbody.innerHTML = products.map((p) => {
        const profit = (p.cost !== null && p.cost !== undefined && p.price !== null) ? (Number(p.price) - Number(p.cost)) : null;
        const profitCls = profit === null ? 'text-slate-400' : (profit >= 0 ? 'text-emerald-600' : 'text-red-600');
        const thumb = productThumb(p);
        const hasCustomImage = !!p.image;
        return `
          <tr class="border-t border-slate-100 hover:bg-slate-50">
            <td class="p-4">
              <div class="w-12 h-12 rounded-lg overflow-hidden bg-slate-100 ring-1 ring-slate-200 relative">
                <img src="${escapeHtml(thumb)}" alt="${escapeHtml(p.name)}" class="w-full h-full object-cover" loading="lazy" onerror="this.src='/assets/images/placeholder.svg'" />
                ${hasCustomImage ? '<span class="absolute top-0 right-0 bg-emerald-500 text-white text-[8px] px-1 rounded-bl" title="Custom photo uploaded">✓</span>' : ''}
              </div>
            </td>
            <td class="p-4">
              <div class="font-medium">${escapeHtml(p.name)}</div>
              <div class="text-xs text-slate-500">${escapeHtml(p.slug || '')}</div>
            </td>
            <td class="p-4 text-slate-600">${escapeHtml(p.category_slug || '—')}</td>
            <td class="p-4 text-right font-medium">${Number(p.price || 0).toLocaleString()}</td>
            <td class="p-4 text-right text-slate-600">${p.cost !== null && p.cost !== undefined ? Number(p.cost).toLocaleString() : '—'}</td>
            <td class="p-4 text-right font-medium ${profitCls}">${profit !== null ? profit.toLocaleString() : '—'}</td>
            <td class="p-4 text-center">${Number(p.total_stock || 0)}</td>
            <td class="p-4 text-right space-x-2 whitespace-nowrap">
              <a href="/admin/product-edit.html?id=${encodeURIComponent(p.id)}" class="text-blue-600 hover:underline text-xs font-medium inline-flex items-center gap-1"><i class="fa-solid fa-pen"></i> Edit</a>
              <button data-del="${encodeURIComponent(p.id)}" class="text-red-600 hover:underline text-xs font-medium inline-flex items-center gap-1"><i class="fa-solid fa-trash"></i> Delete</button>
            </td>
          </tr>`;
      }).join('');
      tbody.querySelectorAll('[data-del]').forEach((b) => {
        b.addEventListener('click', async () => {
          const id = decodeURIComponent(b.dataset.del);
          if (!confirm('Delete this product? It will be removed from the storefront.')) return;
          const res = await fetch('/api/admin/products/' + id, {
            method: 'DELETE',
            headers: { Authorization: 'Bearer ' + token },
          });
          const body = await res.json();
          if (!res.ok) { alert(body.error?.message || 'Delete failed'); return; }
          load();
        });
      });
    }

    document.getElementById('search').addEventListener('input', debounce(load, 300));
    document.getElementById('category-filter').addEventListener('change', load);

    function debounce(fn, ms){ let t; return (...a)=>{ clearTimeout(t); t=setTimeout(()=>fn(...a),ms); }; }
    function escapeHtml(s=''){ return String(s).replace(/[&<>"']/g,(c)=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }

    load();
  </script>
</body>
</html>
PRODUCTSHTML

# =============================================================================
# Add placeholder SVG if missing
# =============================================================================
if [ ! -f public/assets/images/placeholder.svg ]; then
  echo "▶ Writing public/assets/images/placeholder.svg (missing)"
  cat > public/assets/images/placeholder.svg <<'PLACEHOLDER'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 300" width="400" height="300">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#eff6ff"/>
      <stop offset="100%" stop-color="#ecfdf5"/>
    </linearGradient>
  </defs>
  <rect width="400" height="300" fill="url(#bg)"/>
  <g transform="translate(200, 130)" opacity="0.35">
    <rect x="-40" y="-20" width="80" height="60" rx="8" fill="none" stroke="#3b82f6" stroke-width="3"/>
    <circle cx="0" cy="-35" r="15" fill="none" stroke="#10b981" stroke-width="3"/>
  </g>
  <text x="200" y="220" font-family="Inter, system-ui, sans-serif" font-size="14" font-weight="700" fill="#64748b" text-anchor="middle" letter-spacing="2">NEVER GIVE UP</text>
  <text x="200" y="240" font-family="Inter, system-ui, sans-serif" font-size="11" fill="#94a3b8" text-anchor="middle">Image coming soon</text>
</svg>
PLACEHOLDER
fi

# =============================================================================
# Stage
# =============================================================================
echo ""
echo "▶ Staging files…"
git add public/admin/products.html
git add public/assets/images/placeholder.svg 2>/dev/null || true

echo ""
echo "▶ Diff summary:"
git status --short

echo ""
echo "✅ Admin product thumbnails added."
echo ""
echo "Deploy:"
echo "  cd C:\\Users\\hp\\Desktop\\repo-tmp"
echo "  npx wrangler pages deploy public --project-name u-containers-com --branch main --commit-dirty=true"
echo "  git add -A; git commit -m 'feat: product thumbnails in admin products table'; git push origin main"
echo ""
