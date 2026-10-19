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
