import { db } from '../../../../src/db.js';
import { nowISO } from '../../../../src/utils.js';
import { jsonResponse, badRequest, notFound, forbidden, serverError } from '../../../../src/errors.js';
import { getAuthUser } from '../../../../src/auth.js';

const ADMIN_ROLES = ['owner', 'admin'];

async function requireAdmin(ctx) {
  let user = ctx.data?.user;
  if (!user) { user = await getAuthUser(ctx); if (user) ctx.data.user = user; }
  if (!user || !ADMIN_ROLES.includes(user.role)) throw forbidden('Owner or admin only');
  return user;
}

// GET /api/admin/users/:id
export async function onRequestGet(ctx) {
  await requireAdmin(ctx);
  const d = db(ctx.env);
  const user = await d.first(
    'SELECT id, email, name, role, branch_id, created_at, updated_at FROM users WHERE id = ? AND deleted_at IS NULL',
    ctx.params.id
  );
  if (!user) throw notFound('User not found');
  return jsonResponse(user);
}

// PUT /api/admin/users/:id — update name/role/branch
export async function onRequestPut(ctx) {
  const actor = await requireAdmin(ctx);
  const body = await ctx.request.json().catch(() => null);
  if (!body) throw badRequest('Invalid JSON');

  const d = db(ctx.env);
  const existing = await d.first('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL', ctx.params.id);
  if (!existing) throw notFound('User not found');

  // Cannot edit another owner unless you're an owner
  if (existing.role === 'owner' && actor.role !== 'owner') {
    throw forbidden('Only owners can edit owners');
  }
  // Cannot demote yourself
  if (existing.id === (actor.sub || '') && body.role && body.role !== existing.role) {
    throw forbidden('You cannot change your own role');
  }

  const updates = [];
  const params = [];
  if (body.name !== undefined) { updates.push('name = ?'); params.push(String(body.name).trim()); }
  if (body.role !== undefined) {
    if (!['owner', 'admin', 'manager', 'supervisor', 'staff', 'customer'].includes(body.role)) {
      throw badRequest('Invalid role');
    }
    if (body.role === 'owner' && actor.role !== 'owner') throw forbidden('Only owners can promote to owner');
    updates.push('role = ?'); params.push(body.role);
  }
  if (body.branch_id !== undefined) {
    updates.push('branch_id = ?'); params.push(body.branch_id || null);
  }
  if (!updates.length) throw badRequest('No fields to update');

  updates.push('updated_at = ?'); params.push(nowISO());
  params.push(ctx.params.id);

  try {
    await d.run(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`, ...params);
    const updated = await d.first(
      'SELECT id, email, name, role, branch_id, updated_at FROM users WHERE id = ?', ctx.params.id
    );
    return jsonResponse(updated);
  } catch (err) {
    console.error('user update failed', err);
    throw serverError('Could not update user: ' + err.message);
  }
}

// DELETE /api/admin/users/:id — soft delete
export async function onRequestDelete(ctx) {
  const actor = await requireAdmin(ctx);
  const d = db(ctx.env);
  const existing = await d.first('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL', ctx.params.id);
  if (!existing) throw notFound('User not found');

  // Cannot delete yourself
  if (existing.id === (actor.sub || '')) throw forbidden('You cannot delete your own account');
  // Cannot delete owners unless you're owner
  if (existing.role === 'owner' && actor.role !== 'owner') throw forbidden('Only owners can delete owners');

  await d.run(
    'UPDATE users SET deleted_at = ?, updated_at = ? WHERE id = ?',
    nowISO(), nowISO(), ctx.params.id
  );
  return jsonResponse({ ok: true, deleted: ctx.params.id });
}
