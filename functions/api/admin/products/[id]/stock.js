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
