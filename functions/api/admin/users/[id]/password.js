import { db } from '../../../../../src/db.js';
import { hashPassword } from '../../../../../src/auth.js';
import { nowISO } from '../../../../../src/utils.js';
import { jsonResponse, badRequest, forbidden, notFound, serverError } from '../../../../../src/errors.js';
import { getAuthUser } from '../../../../../src/auth.js';

const ADMIN_ROLES = ['owner', 'admin'];

async function requireAdmin(ctx) {
  let user = ctx.data?.user;
  if (!user) { user = await getAuthUser(ctx); if (user) ctx.data.user = user; }
  if (!user || !ADMIN_ROLES.includes(user.role)) throw forbidden('Owner or admin only');
  return user;
}

// POST /api/admin/users/:id/password — set a new password for a user
export async function onRequestPost(ctx) {
  const actor = await requireAdmin(ctx);
  const body = await ctx.request.json().catch(() => null);
  if (!body || !body.password) throw badRequest('password required');
  if (body.password.length < 8) throw badRequest('Password must be at least 8 characters');

  const d = db(ctx.env);
  const existing = await d.first('SELECT * FROM users WHERE id = ? AND deleted_at IS NULL', ctx.params.id);
  if (!existing) throw notFound('User not found');

  // Cannot change another owner's password unless you're owner
  if (existing.role === 'owner' && actor.role !== 'owner') {
    throw forbidden('Only owners can change owner passwords');
  }

  try {
    const hash = await hashPassword(body.password);
    await d.run(
      'UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?',
      hash, nowISO(), ctx.params.id
    );
    return jsonResponse({ ok: true });
  } catch (err) {
    console.error('password change failed', err);
    throw serverError('Could not change password: ' + err.message);
  }
}
