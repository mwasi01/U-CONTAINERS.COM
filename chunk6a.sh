#!/usr/bin/env bash
# chunk6a.sh — products CRUD (create, edit, delete, cost tracking)
set -euo pipefail
cd "$(dirname "$0")"
echo "▶ Repo root: $(pwd)"

test -d public   || { echo "FATAL: public/ missing"; exit 1; }
test -d functions || { echo "FATAL: functions/ missing"; exit 1; }
test -d migrations || { echo "FATAL: migrations/ missing"; exit 1; }

# =============================================================================
# 1. Migration — add cost, stock, audit columns to products
# =============================================================================
echo "▶ Writing migrations/0045_product_management.sql"
cat > migrations/0045_product_management.sql <<'SQL'
-- 0045_product_management.sql — add cost, audit fields, and per-branch stock

-- cost: purchase cost per unit (used for profit calculation). NULL means unknown.
ALTER TABLE products ADD COLUMN cost REAL DEFAULT NULL;

-- updated_by: audit trail — who last edited the product
ALTER TABLE products ADD COLUMN updated_by TEXT DEFAULT NULL;

-- Per-branch stock levels (option 3: available at all branches, stock per branch)
CREATE TABLE IF NOT EXISTS product_stock (
  product_id  TEXT NOT NULL,
  branch_id   TEXT NOT NULL,
  quantity    INTEGER NOT NULL DEFAULT 0,
  updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (product_id, branch_id)
);

CREATE INDEX IF NOT EXISTS idx_product_stock_branch ON product_stock(branch_id);

-- Backfill: for each existing product, create stock rows for both branches with 0 qty
INSERT OR IGNORE INTO product_stock (product_id, branch_id, quantity)
SELECT p.id, b.id, 0
FROM products p
CROSS JOIN branches b;
SQL

# =============================================================================
# 2. functions/api/admin/products/index.js — list + create
# =============================================================================
echo "▶ Writing functions/api/admin/products/index.js"
mkdir -p functions/api/admin/products
cat > functions/api/admin/products/index.js <<'LISTCREATE'
import { db } from '../../../../src/db.js';
import { uuid, nowISO } from '../../../../src/utils.js';
import { jsonResponse, badRequest, forbidden, serverError } from '../../../../src/errors.js';

const EDIT_ROLES = ['owner', 'admin', 'manager'];

function requireEditor(ctx) {
  const user = ctx.data?.user;
  if (!user) {
    const e = new Error('Sign in required'); e.status = 401; e.code = 'unauthorized';
    throw e;
  }
  if (!EDIT_ROLES.includes(user.role)) {
    throw forbidden('Only owner, admin, or manager can edit products');
  }
  return user;
}

function slugify(name) {
  return String(name).toLowerCase().trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);
}

// GET /api/admin/products — list all products (with cost, stock counts)
export async function onRequestGet(ctx) {
  requireEditor(ctx);
  const d = db(ctx.env);
  const url = new URL(ctx.request.url);
  const q = url.searchParams.get('q') || '';
  const category = url.searchParams.get('category') || '';

  let sql = `
    SELECT p.*,
      COALESCE((SELECT SUM(quantity) FROM product_stock WHERE product_id = p.id), 0) AS total_stock
    FROM products p
    WHERE p.deleted_at IS NULL
  `;
  const params = [];
  if (q) { sql += ' AND p.name LIKE ?'; params.push('%' + q + '%'); }
  if (category) { sql += ' AND p.category_slug = ?'; params.push(category); }
  sql += ' ORDER BY p.created_at DESC';

  const products = await d.all(sql, ...params);
  return jsonResponse(products);
}

// POST /api/admin/products — create new product
export async function onRequestPost(ctx) {
  const user = requireEditor(ctx);
  const body = await ctx.request.json().catch(() => null);
  if (!body) throw badRequest('Invalid JSON');

  const { name, price, cost, category_slug, description, status } = body;
  if (!name || typeof name !== 'string') throw badRequest('name is required');
  if (price === undefined || price === null) throw badRequest('price is required');
  const priceNum = Number(price);
  if (isNaN(priceNum) || priceNum < 0) throw badRequest('price must be a non-negative number');
  const costNum = cost === undefined || cost === null || cost === '' ? null : Number(cost);
  if (costNum !== null && (isNaN(costNum) || costNum < 0)) throw badRequest('cost must be a non-negative number');

  const d = db(ctx.env);
  const id = 'p_' + uuid().slice(0, 8);
  let slug = slugify(name);
  // Ensure slug uniqueness
  const existing = await d.first('SELECT id FROM products WHERE slug = ?', slug);
  if (existing) slug = slug + '-' + uuid().slice(0, 4);

  const now = nowISO();
  try {
    await d.run(
      `INSERT INTO products (id, name, slug, description, category_slug, price, cost, status, updated_by, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      id, name.trim(), slug, description || null, category_slug || null,
      priceNum, costNum, status || 'active', user.sub || user.email, now, now
    );
    // Seed stock rows for all branches
    await d.run(
      `INSERT INTO product_stock (product_id, branch_id, quantity)
       SELECT ?, id, 0 FROM branches`,
      id
    );
    const created = await d.first('SELECT * FROM products WHERE id = ?', id);
    return jsonResponse(created);
  } catch (err) {
    console.error('product create failed', err);
    throw serverError('Could not create product: ' + err.message);
  }
}
LISTCREATE

# =============================================================================
# 3. functions/api/admin/products/[id].js — get, update, delete
# =============================================================================
echo "▶ Writing functions/api/admin/products/[id].js"
cat > functions/api/admin/products/[id].js <<'GETPUTDEL'
import { db } from '../../../../src/db.js';
import { nowISO } from '../../../../src/utils.js';
import { jsonResponse, badRequest, notFound, forbidden, serverError } from '../../../../src/errors.js';

const EDIT_ROLES = ['owner', 'admin', 'manager'];

function requireEditor(ctx) {
  const user = ctx.data?.user;
  if (!user) {
    const e = new Error('Sign in required'); e.status = 401; e.code = 'unauthorized';
    throw e;
  }
  if (!EDIT_ROLES.includes(user.role)) {
    throw forbidden('Only owner, admin, or manager can edit products');
  }
  return user;
}

// GET /api/admin/products/:id
export async function onRequestGet(ctx) {
  requireEditor(ctx);
  const d = db(ctx.env);
  const product = await d.first('SELECT * FROM products WHERE id = ? AND deleted_at IS NULL', ctx.params.id);
  if (!product) throw notFound('Product not found');
  const stock = await d.all(
    `SELECT ps.branch_id, b.name AS branch_name, ps.quantity
     FROM product_stock ps
     JOIN branches b ON b.id = ps.branch_id
     WHERE ps.product_id = ?`,
    ctx.params.id
  );
  return jsonResponse({ ...product, stock });
}

// PUT /api/admin/products/:id — update product
export async function onRequestPut(ctx) {
  const user = requireEditor(ctx);
  const body = await ctx.request.json().catch(() => null);
  if (!body) throw badRequest('Invalid JSON');

  const d = db(ctx.env);
  const existing = await d.first('SELECT * FROM products WHERE id = ? AND deleted_at IS NULL', ctx.params.id);
  if (!existing) throw notFound('Product not found');

  const updates = [];
  const params = [];

  if (body.name !== undefined) {
    if (!body.name || typeof body.name !== 'string') throw badRequest('name cannot be empty');
    updates.push('name = ?'); params.push(body.name.trim());
  }
  if (body.price !== undefined) {
    const n = Number(body.price);
    if (isNaN(n) || n < 0) throw badRequest('price must be a non-negative number');
    updates.push('price = ?'); params.push(n);
  }
  if (body.cost !== undefined) {
    const n = body.cost === null || body.cost === '' ? null : Number(body.cost);
    if (n !== null && (isNaN(n) || n < 0)) throw badRequest('cost must be a non-negative number');
    updates.push('cost = ?'); params.push(n);
  }
  if (body.description !== undefined) {
    updates.push('description = ?'); params.push(body.description || null);
  }
  if (body.category_slug !== undefined) {
    updates.push('category_slug = ?'); params.push(body.category_slug || null);
  }
  if (body.status !== undefined) {
    if (!['active', 'draft', 'archived'].includes(body.status)) throw badRequest('invalid status');
    updates.push('status = ?'); params.push(body.status);
  }
  if (!updates.length) throw badRequest('No fields to update');

  updates.push('updated_at = ?'); params.push(nowISO());
  updates.push('updated_by = ?'); params.push(user.sub || user.email);
  params.push(ctx.params.id);

  try {
    await d.run(`UPDATE products SET ${updates.join(', ')} WHERE id = ?`, ...params);
    const updated = await d.first('SELECT * FROM products WHERE id = ?', ctx.params.id);
    return jsonResponse(updated);
  } catch (err) {
    console.error('product update failed', err);
    throw serverError('Could not update product: ' + err.message);
  }
}

// DELETE /api/admin/products/:id — soft-delete
export async function onRequestDelete(ctx) {
  const user = requireEditor(ctx);
  const d = db(ctx.env);
  const existing = await d.first('SELECT id FROM products WHERE id = ? AND deleted_at IS NULL', ctx.params.id);
  if (!existing) throw notFound('Product not found');

  try {
    await d.run(
      'UPDATE products SET deleted_at = ?, updated_at = ?, updated_by = ? WHERE id = ?',
      nowISO(), nowISO(), user.sub || user.email, ctx.params.id
    );
    return jsonResponse({ ok: true, deleted: ctx.params.id });
  } catch (err) {
    console.error('product delete failed', err);
    throw serverError('Could not delete product: ' + err.message);
  }
}
GETPUTDEL

# =============================================================================
# 4. functions/api/admin/products/[id]/stock.js — update per-branch stock
# =============================================================================
echo "▶ Writing functions/api/admin/products/[id]/stock.js"
mkdir -p 'functions/api/admin/products/[id]'
cat > 'functions/api/admin/products/[id]/stock.js' <<'STOCK'
import { db } from '../../../../../src/db.js';
import { nowISO } from '../../../../../src/utils.js';
import { jsonResponse, badRequest, forbidden, serverError } from '../../../../../src/errors.js';

const EDIT_ROLES = ['owner', 'admin', 'manager'];

export async function onRequestPut(ctx) {
  const user = ctx.data?.user;
  if (!user || !EDIT_ROLES.includes(user.role)) {
    throw forbidden('Only owner, admin, or manager can edit stock');
  }

  const body = await ctx.request.json().catch(() => null);
  if (!body || !body.branch_id || body.quantity === undefined) {
    throw badRequest('branch_id and quantity required');
  }
  const qty = Number(body.quantity);
  if (isNaN(qty) || qty < 0) throw badRequest('quantity must be a non-negative number');

  const d = db(ctx.env);
  try {
    await d.run(
      `INSERT INTO product_stock (product_id, branch_id, quantity, updated_at)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(product_id, branch_id) DO UPDATE SET quantity = ?, updated_at = ?`,
      ctx.params.id, body.branch_id, qty, nowISO(), qty, nowISO()
    );
    return jsonResponse({ ok: true });
  } catch (err) {
    console.error('stock update failed', err);
    throw serverError('Could not update stock: ' + err.message);
  }
}
STOCK

# =============================================================================
# 5. public/admin/products.html — products table
# =============================================================================
echo "▶ Writing public/admin/products.html"
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
    <div class="max-w-6xl mx-auto">
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 class="text-3xl font-extrabold">Products</h1>
          <p class="text-slate-500 mt-1">Manage your catalog, prices, and costs.</p>
        </div>
        <a href="/admin/product-new.html" class="inline-flex items-center gap-2 px-5 py-2.5 rounded-md bg-brand-600 text-white font-semibold hover:bg-brand-700" style="background:#2563eb;">
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
                <th class="text-left p-4">Product</th>
                <th class="text-left p-4">Category</th>
                <th class="text-right p-4">Price (KES)</th>
                <th class="text-right p-4">Cost (KES)</th>
                <th class="text-right p-4">Profit/unit</th>
                <th class="text-center p-4">Stock</th>
                <th class="text-right p-4">Actions</th>
              </tr>
            </thead>
            <tbody id="tbody"><tr><td colspan="7" class="p-6 text-center text-slate-500">Loading…</td></tr></tbody>
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

    async function load() {
      const q = document.getElementById('search').value.trim();
      const cat = document.getElementById('category-filter').value;
      const params = new URLSearchParams();
      if (q) params.set('q', q);
      if (cat) params.set('category', cat);
      const url = '/api/admin/products' + (params.toString() ? '?' + params.toString() : '');
      const res = await fetch(url, { headers: { Authorization: 'Bearer ' + token } });
      const body = await res.json();
      if (!res.ok) { document.getElementById('tbody').innerHTML = '<tr><td colspan="7" class="p-6 text-center text-red-600">' + (body.error?.message || 'Failed') + '</td></tr>'; return; }
      products = body.data || [];
      renderTable();
    }

    function renderTable() {
      const tbody = document.getElementById('tbody');
      if (!products.length) {
        tbody.innerHTML = '<tr><td colspan="7" class="p-6 text-center text-slate-500">No products. <a href="/admin/product-new.html" class="text-blue-600 hover:underline">Add one →</a></td></tr>';
        return;
      }
      tbody.innerHTML = products.map((p) => {
        const profit = (p.cost !== null && p.cost !== undefined && p.price !== null) ? (Number(p.price) - Number(p.cost)) : null;
        const profitCls = profit === null ? 'text-slate-400' : (profit >= 0 ? 'text-emerald-600' : 'text-red-600');
        return `
          <tr class="border-t border-slate-100 hover:bg-slate-50">
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
              <a href="/admin/product-edit.html?id=${encodeURIComponent(p.id)}" class="text-blue-600 hover:underline text-xs font-medium">Edit</a>
              <button data-del="${encodeURIComponent(p.id)}" class="text-red-600 hover:underline text-xs font-medium">Delete</button>
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
# 6. public/admin/product-new.html — create form
# =============================================================================
echo "▶ Writing public/admin/product-new.html"
cat > public/admin/product-new.html <<'NEWHTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Add product · Admin · NEVER GIVE UP ENTERPRISE</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />
</head>
<body class="font-sans bg-slate-100 text-slate-800 min-h-screen">
  <header class="bg-slate-900 text-white px-6 h-14 flex items-center justify-between">
    <a href="/admin/products.html" class="flex items-center gap-2 text-sm font-bold"><i class="fa-solid fa-arrow-left"></i> Back to products</a>
    <span class="text-sm">Add product</span>
  </header>

  <main class="max-w-2xl mx-auto p-6">
    <div class="bg-white rounded-2xl ring-1 ring-slate-100 p-6">
      <h1 class="text-2xl font-extrabold">Add new product</h1>
      <p class="text-slate-500 mt-1 text-sm">Enter product details below. Fields marked * are required.</p>

      <div id="err" class="hidden mt-4 p-3 rounded-md bg-red-50 border border-red-200 text-red-700 text-sm"></div>

      <form id="form" class="mt-6 space-y-4">
        <div>
          <label class="text-sm font-medium">Product name *</label>
          <input name="name" required class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500" placeholder="e.g. 300L Open Plastic Drum" />
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="text-sm font-medium">Selling price (KES) *</label>
            <input name="price" type="number" min="0" step="0.01" required class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500" placeholder="3500" />
          </div>
          <div>
            <label class="text-sm font-medium">Cost price (KES)</label>
            <input name="cost" type="number" min="0" step="0.01" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500" placeholder="e.g. 2200" />
            <p class="text-xs text-slate-500 mt-1">Used for profit calculation. Leave blank if unknown.</p>
          </div>
        </div>
        <div>
          <label class="text-sm font-medium">Category</label>
          <select name="category_slug" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2">
            <option value="">— Select category —</option>
            <option value="drums-containers">Drums & Containers</option>
            <option value="jikos">Jikos</option>
            <option value="farming-tools">Farming Tools</option>
            <option value="accessories">Accessories</option>
          </select>
        </div>
        <div>
          <label class="text-sm font-medium">Description</label>
          <textarea name="description" rows="4" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500" placeholder="Capacity, material, features…"></textarea>
        </div>
        <div>
          <label class="text-sm font-medium">Status</label>
          <select name="status" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2">
            <option value="active">Active (visible on storefront)</option>
            <option value="draft">Draft (hidden)</option>
          </select>
        </div>

        <div class="flex gap-3 pt-2">
          <a href="/admin/products.html" class="flex-1 text-center px-5 py-2.5 rounded-md bg-white ring-1 ring-slate-200 font-medium hover:ring-slate-300">Cancel</a>
          <button type="submit" class="flex-1 px-5 py-2.5 rounded-md bg-blue-600 text-white font-semibold hover:bg-blue-700">
            <i class="fa-solid fa-plus"></i> Create product
          </button>
        </div>
      </form>
    </div>
  </main>

  <script>
    const token = localStorage.getItem('ngu.token');
    const user = (() => { try { return JSON.parse(localStorage.getItem('ngu.user') || 'null'); } catch { return null; } })();
    if (!token || !user || !['owner','admin','manager'].includes(user.role)) {
      location.href = '/admin/login.html';
    }

    const form = document.getElementById('form');
    const err = document.getElementById('err');

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      err.classList.add('hidden');
      const data = Object.fromEntries(new FormData(form));
      if (data.cost === '') delete data.cost;
      if (data.category_slug === '') delete data.category_slug;
      try {
        const res = await fetch('/api/admin/products', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
          body: JSON.stringify(data),
        });
        const body = await res.json();
        if (!res.ok || body.error) throw new Error(body.error?.message || 'Create failed');
        location.href = '/admin/products.html';
      } catch (e) {
        err.textContent = e.message;
        err.classList.remove('hidden');
      }
    });
  </script>
</body>
</html>
NEWHTML

# =============================================================================
# 7. public/admin/product-edit.html — edit form
# =============================================================================
echo "▶ Writing public/admin/product-edit.html"
cat > public/admin/product-edit.html <<'EDITHTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Edit product · Admin · NEVER GIVE UP ENTERPRISE</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />
</head>
<body class="font-sans bg-slate-100 text-slate-800 min-h-screen">
  <header class="bg-slate-900 text-white px-6 h-14 flex items-center justify-between">
    <a href="/admin/products.html" class="flex items-center gap-2 text-sm font-bold"><i class="fa-solid fa-arrow-left"></i> Back to products</a>
    <span class="text-sm">Edit product</span>
  </header>

  <main class="max-w-2xl mx-auto p-6">
    <div class="bg-white rounded-2xl ring-1 ring-slate-100 p-6">
      <h1 class="text-2xl font-extrabold">Edit product</h1>
      <p class="text-slate-500 mt-1 text-sm" id="meta">Loading…</p>

      <div id="err" class="hidden mt-4 p-3 rounded-md bg-red-50 border border-red-200 text-red-700 text-sm"></div>
      <div id="ok" class="hidden mt-4 p-3 rounded-md bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm"></div>

      <form id="form" class="mt-6 space-y-4">
        <div>
          <label class="text-sm font-medium">Product name *</label>
          <input name="name" required class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500" />
        </div>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="text-sm font-medium">Selling price (KES) *</label>
            <input name="price" type="number" min="0" step="0.01" required class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div>
            <label class="text-sm font-medium">Cost price (KES)</label>
            <input name="cost" type="number" min="0" step="0.01" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
        </div>
        <div>
          <label class="text-sm font-medium">Category</label>
          <select name="category_slug" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2">
            <option value="">— None —</option>
            <option value="drums-containers">Drums & Containers</option>
            <option value="jikos">Jikos</option>
            <option value="farming-tools">Farming Tools</option>
            <option value="accessories">Accessories</option>
          </select>
        </div>
        <div>
          <label class="text-sm font-medium">Description</label>
          <textarea name="description" rows="4" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2"></textarea>
        </div>
        <div>
          <label class="text-sm font-medium">Status</label>
          <select name="status" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2">
            <option value="active">Active (visible)</option>
            <option value="draft">Draft (hidden)</option>
            <option value="archived">Archived</option>
          </select>
        </div>

        <div class="pt-4 border-t border-slate-200">
          <h2 class="text-sm font-bold mb-3">Stock per branch</h2>
          <div id="stock-editor" class="space-y-2"></div>
        </div>

        <div class="flex gap-3 pt-2">
          <a href="/admin/products.html" class="flex-1 text-center px-5 py-2.5 rounded-md bg-white ring-1 ring-slate-200 font-medium hover:ring-slate-300">Cancel</a>
          <button type="submit" class="flex-1 px-5 py-2.5 rounded-md bg-blue-600 text-white font-semibold hover:bg-blue-700">
            <i class="fa-solid fa-save"></i> Save changes
          </button>
        </div>
      </form>
    </div>
  </main>

  <script>
    const token = localStorage.getItem('ngu.token');
    const user = (() => { try { return JSON.parse(localStorage.getItem('ngu.user') || 'null'); } catch { return null; } })();
    if (!token || !user || !['owner','admin','manager'].includes(user.role)) {
      location.href = '/admin/login.html';
    }

    const id = new URLSearchParams(location.search).get('id');
    if (!id) { document.body.innerHTML = '<p class="p-6 text-red-600">Missing product id.</p>'; throw new Error('no id'); }

    const form = document.getElementById('form');
    const err = document.getElementById('err');
    const ok = document.getElementById('ok');
    const meta = document.getElementById('meta');

    let product = null;

    async function load() {
      try {
        const res = await fetch('/api/admin/products/' + encodeURIComponent(id), {
          headers: { Authorization: 'Bearer ' + token },
        });
        const body = await res.json();
        if (!res.ok || body.error) throw new Error(body.error?.message || 'Load failed');
        product = body.data;
        meta.textContent = 'Editing: ' + product.id;

        form.name.value = product.name || '';
        form.price.value = product.price || 0;
        form.cost.value = product.cost !== null && product.cost !== undefined ? product.cost : '';
        form.category_slug.value = product.category_slug || '';
        form.description.value = product.description || '';
        form.status.value = product.status || 'active';

        renderStock();
      } catch (e) {
        err.textContent = e.message;
        err.classList.remove('hidden');
      }
    }

    function renderStock() {
      const root = document.getElementById('stock-editor');
      const stock = product.stock || [];
      if (!stock.length) { root.innerHTML = '<p class="text-sm text-slate-500">No stock rows.</p>'; return; }
      root.innerHTML = stock.map((s) => `
        <div class="flex items-center gap-3">
          <span class="w-32 text-sm text-slate-700">${escapeHtml(s.branch_name || s.branch_id)}</span>
          <input type="number" min="0" value="${s.quantity || 0}" data-branch="${escapeHtml(s.branch_id)}" class="flex-1 rounded-md border border-slate-300 px-3 py-1.5 text-sm" />
        </div>
      `).join('');
      root.querySelectorAll('[data-branch]').forEach((input) => {
        input.addEventListener('change', async () => {
          const branchId = input.dataset.branch;
          const qty = Number(input.value) || 0;
          try {
            const res = await fetch('/api/admin/products/' + encodeURIComponent(id) + '/stock', {
              method: 'PUT',
              headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
              body: JSON.stringify({ branch_id: branchId, quantity: qty }),
            });
            const body = await res.json();
            if (!res.ok || body.error) throw new Error(body.error?.message || 'Update failed');
            ok.textContent = 'Stock updated for ' + branchId;
            ok.classList.remove('hidden');
            setTimeout(() => ok.classList.add('hidden'), 2000);
          } catch (e) {
            err.textContent = e.message;
            err.classList.remove('hidden');
          }
        });
      });
    }

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      err.classList.add('hidden');
      ok.classList.add('hidden');
      const data = Object.fromEntries(new FormData(form));
      if (data.cost === '') data.cost = null;
      try {
        const res = await fetch('/api/admin/products/' + encodeURIComponent(id), {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
          body: JSON.stringify(data),
        });
        const body = await res.json();
        if (!res.ok || body.error) throw new Error(body.error?.message || 'Update failed');
        ok.textContent = 'Changes saved.';
        ok.classList.remove('hidden');
        setTimeout(() => location.href = '/admin/products.html', 800);
      } catch (e) {
        err.textContent = e.message;
        err.classList.remove('hidden');
      }
    });

    function escapeHtml(s=''){ return String(s).replace(/[&<>"']/g,(c)=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }

    load();
  </script>
</body>
</html>
EDITHTML

# =============================================================================
# 8. Update admin/index.html — add "Products" nav link
# =============================================================================
echo "▶ Updating admin/index.html sidebar"
if [ -f public/admin/index.html ]; then
  # Insert Products link after Dashboard if it's not already there
  if ! grep -q 'href="/admin/products.html"' public/admin/index.html; then
    sed -i 's|<a href="/products/" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-box w-4"></i> Products</a>|<a href="/admin/products.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-box w-4"></i> Products</a>|' public/admin/index.html
  fi
  if ! grep -q 'href="/admin/analytics.html"' public/admin/index.html; then
    sed -i 's|<a href="/account/orders.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-receipt w-4"></i> Orders</a>|<a href="/admin/analytics.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-chart-line w-4"></i> Analytics</a>\n      <a href="/account/orders.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-receipt w-4"></i> Orders</a>|' public/admin/index.html
  fi
fi

# =============================================================================
# 9. Stage
# =============================================================================
echo ""
echo "▶ Staging files…"
git add migrations/0045_product_management.sql
git add functions/api/admin/products/index.js
git add 'functions/api/admin/products/[id].js'
git add 'functions/api/admin/products/[id]/stock.js'
git add public/admin/products.html public/admin/product-new.html public/admin/product-edit.html
git add public/admin/index.html 2>/dev/null || true

echo ""
echo "▶ Diff summary:"
git status --short

echo ""
echo "✅ Chunk 6a written."
echo ""
echo "Next (PowerShell):"
echo "  1. Apply migration:"
echo "     npx wrangler d1 migrations apply ngu-platform-db --remote"
echo "  2. Deploy:"
echo "     npx wrangler pages deploy public --project-name u-containers-com --branch main --commit-dirty=true"
echo "  3. Commit + push (using semicolons, not &&):"
echo "     git add -A; git commit -m 'feat: admin products CRUD with cost tracking'; git push origin main"
echo ""
