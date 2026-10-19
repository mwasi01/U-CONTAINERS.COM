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
