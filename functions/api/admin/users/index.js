import { db } from '../../../../src/db.js';
import { uuid, nowISO } from '../../../../src/utils.js';
import { hashPassword } from '../../../../src/auth.js';
import { jsonResponse, badRequest, forbidden, serverError } from '../../../../src/errors.js';
import { getAuthUser } from '../../../../src/auth.js';

const ADMIN_ROLES = ['owner', 'admin'];

async function requireAdmin(ctx) {
  let user = ctx.data?.user;
  if (!user) { user = await getAuthUser(ctx); if (user) ctx.data.user = user; }
  if (!user || !ADMIN_ROLES.includes(user.role)) throw forbidden('Owner or admin only');
  return user;
}

// GET /api/admin/users — list all users
export async function onRequestGet(ctx) {
  await requireAdmin(ctx);
  const d = db(ctx.env);
  const users = await d.all(
    `SELECT id, email, name, role, branch_id, created_at, updated_at
     FROM users WHERE deleted_at IS NULL ORDER BY created_at DESC`
  );
  return jsonResponse(users);
}

// POST /api/admin/users — create new user
export async function onRequestPost(ctx) {
  const actor = await requireAdmin(ctx);
  const body = await ctx.request.json().catch(() => null);
  if (!body) throw badRequest('Invalid JSON');

  const { email, password, name, role, branch_id } = body;
  if (!email || !password || !name) throw badRequest('email, password, name required');
  if (password.length < 8) throw badRequest('Password must be at least 8 characters');
  if (!['owner', 'admin', 'manager', 'supervisor', 'staff', 'customer'].includes(role)) {
    throw badRequest('Invalid role');
  }
  // Only owner can create another owner
  if (role === 'owner' && actor.role !== 'owner') throw forbidden('Only owners can create owners');

  const d = db(ctx.env);
  const existing = await d.first('SELECT id FROM users WHERE email = ?', email.toLowerCase());
  if (existing) throw badRequest('Email already registered');

  const id = uuid();
  const hash = await hashPassword(password);
  const now = nowISO();

  try {
    await d.run(
      `INSERT INTO users (id, email, password_hash, name, role, branch_id, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      id, email.toLowerCase(), hash, name, role, branch_id || null, now, now
    );
    const created = await d.first(
      'SELECT id, email, name, role, branch_id, created_at FROM users WHERE id = ?', id
    );
    return jsonResponse(created);
  } catch (err) {
    console.error('user create failed', err);
    throw serverError('Could not create user: ' + err.message);
  }
}
