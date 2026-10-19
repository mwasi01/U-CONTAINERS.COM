#!/usr/bin/env bash
# chunk-admin-users.sh — admin user management (add, edit, change password)
set -euo pipefail
cd "$(dirname "$0")"
echo "▶ Repo root: $(pwd)"

# =============================================================================
# 1. functions/api/admin/users/index.js — list + create
# =============================================================================
echo "▶ Writing functions/api/admin/users/index.js"
mkdir -p functions/api/admin/users
cat > functions/api/admin/users/index.js <<'USERS'
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
USERS

# =============================================================================
# 2. functions/api/admin/users/[id].js — update role/name/branch, delete
# =============================================================================
echo "▶ Writing functions/api/admin/users/[id].js"
cat > 'functions/api/admin/users/[id].js' <<'USERID'
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
USERID

# =============================================================================
# 3. functions/api/admin/users/[id]/password.js — change password
# =============================================================================
echo "▶ Writing functions/api/admin/users/[id]/password.js"
mkdir -p 'functions/api/admin/users/[id]'
cat > 'functions/api/admin/users/[id]/password.js' <<'PWD'
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
PWD

# =============================================================================
# 4. public/admin/users.html — list + create + edit + change password
# =============================================================================
echo "▶ Writing public/admin/users.html"
cat > public/admin/users.html <<'USERSHTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Users · Admin · NEVER GIVE UP ENTERPRISE</title>
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
      <a href="/admin/best-sellers.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-trophy w-4"></i> Best sellers</a>
      <a href="/admin/branch-assign.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-code-branch w-4"></i> Branch assign</a>
      <a href="/admin/users.html" class="flex items-center gap-3 px-3 py-2 rounded-md bg-slate-800 text-white"><i class="fa-solid fa-user-shield w-4"></i> Users</a>
      <a href="/account/orders.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-receipt w-4"></i> Orders</a>
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
    <span class="text-sm font-bold">Users</span>
    <span class="w-6"></span>
  </header>

  <main class="lg:ml-64 min-h-screen p-6">
    <div class="max-w-6xl mx-auto">
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 class="text-3xl font-extrabold">Users</h1>
          <p class="text-slate-500 mt-1">Manage staff, admins, and customer accounts.</p>
        </div>
        <button id="add-btn" class="inline-flex items-center gap-2 px-5 py-2.5 rounded-md bg-blue-600 text-white font-semibold hover:bg-blue-700">
          <i class="fa-solid fa-user-plus"></i> Add user
        </button>
      </div>

      <div class="mt-6 bg-white rounded-2xl ring-1 ring-slate-100 overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead class="bg-slate-50 text-slate-600 text-xs uppercase tracking-wider">
              <tr>
                <th class="text-left p-4">Name</th>
                <th class="text-left p-4">Email</th>
                <th class="text-left p-4">Role</th>
                <th class="text-left p-4">Branch</th>
                <th class="text-right p-4">Actions</th>
              </tr>
            </thead>
            <tbody id="tbody"><tr><td colspan="5" class="p-6 text-center text-slate-500">Loading…</td></tr></tbody>
          </table>
        </div>
      </div>
    </div>
  </main>

  <!-- Add user modal -->
  <div id="add-modal" class="hidden fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
    <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full p-6">
      <h2 class="text-xl font-extrabold">Add user</h2>
      <p class="text-sm text-slate-500 mt-1">Create a new admin, manager, staff, or customer account.</p>
      <div id="add-err" class="hidden mt-3 p-3 rounded-md bg-red-50 border border-red-200 text-red-700 text-sm"></div>
      <form id="add-form" class="mt-5 space-y-3">
        <div><label class="text-sm font-medium">Name</label><input name="name" required class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2" /></div>
        <div><label class="text-sm font-medium">Email</label><input name="email" type="email" required class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2" /></div>
        <div><label class="text-sm font-medium">Password</label><input name="password" type="password" required minlength="8" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2" /></div>
        <div>
          <label class="text-sm font-medium">Role</label>
          <select name="role" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2">
            <option value="staff">Staff</option>
            <option value="manager">Manager</option>
            <option value="supervisor">Supervisor</option>
            <option value="admin">Admin</option>
            <option value="customer">Customer</option>
          </select>
        </div>
        <div>
          <label class="text-sm font-medium">Branch (optional)</label>
          <select name="branch_id" id="add-branch" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2">
            <option value="">— No branch —</option>
          </select>
        </div>
        <div class="flex gap-3 pt-2">
          <button type="button" data-close-add class="flex-1 px-4 py-2 rounded-md bg-white ring-1 ring-slate-200 font-medium">Cancel</button>
          <button type="submit" class="flex-1 px-4 py-2 rounded-md bg-blue-600 text-white font-semibold hover:bg-blue-700">Create user</button>
        </div>
      </form>
    </div>
  </div>

  <!-- Edit user modal -->
  <div id="edit-modal" class="hidden fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
    <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full p-6">
      <h2 class="text-xl font-extrabold">Edit user</h2>
      <p class="text-sm text-slate-500 mt-1" id="edit-sub"></p>
      <div id="edit-err" class="hidden mt-3 p-3 rounded-md bg-red-50 border border-red-200 text-red-700 text-sm"></div>
      <div id="edit-ok" class="hidden mt-3 p-3 rounded-md bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm"></div>
      <form id="edit-form" class="mt-5 space-y-3">
        <input type="hidden" name="id" />
        <div><label class="text-sm font-medium">Name</label><input name="name" required class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2" /></div>
        <div>
          <label class="text-sm font-medium">Role</label>
          <select name="role" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2">
            <option value="staff">Staff</option>
            <option value="manager">Manager</option>
            <option value="supervisor">Supervisor</option>
            <option value="admin">Admin</option>
            <option value="owner">Owner</option>
            <option value="customer">Customer</option>
          </select>
        </div>
        <div>
          <label class="text-sm font-medium">Branch</label>
          <select name="branch_id" id="edit-branch" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2">
            <option value="">— No branch —</option>
          </select>
        </div>
        <div class="pt-3 border-t border-slate-200">
          <label class="text-sm font-medium">Reset password (optional)</label>
          <input name="password" type="password" placeholder="Leave blank to keep current" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2" />
          <p class="text-xs text-slate-500 mt-1">Min 8 chars. If set, user must use this to log in next time.</p>
        </div>
        <div class="flex gap-3 pt-2">
          <button type="button" data-close-edit class="flex-1 px-4 py-2 rounded-md bg-white ring-1 ring-slate-200 font-medium">Cancel</button>
          <button type="submit" class="flex-1 px-4 py-2 rounded-md bg-blue-600 text-white font-semibold hover:bg-blue-700">Save changes</button>
        </div>
        <div class="pt-2 border-t border-slate-200">
          <button type="button" id="delete-user-btn" class="w-full px-4 py-2 rounded-md bg-red-50 text-red-700 font-medium hover:bg-red-100">
            <i class="fa-solid fa-trash"></i> Delete user
          </button>
        </div>
      </form>
    </div>
  </div>

  <script>
    const token = localStorage.getItem('ngu.token');
    const user = (() => { try { return JSON.parse(localStorage.getItem('ngu.user') || 'null'); } catch { return null; } })();
    if (!token || !user || !['owner','admin'].includes(user.role)) {
      location.href = '/admin/login.html';
    }
    document.getElementById('user-email').textContent = user?.email || '—';
    document.getElementById('menu-btn')?.addEventListener('click', () => document.getElementById('sidebar').classList.toggle('-translate-x-full'));
    document.getElementById('logout').addEventListener('click', () => {
      localStorage.removeItem('ngu.token'); localStorage.removeItem('ngu.user');
      location.href = '/admin/login.html';
    });

    let branches = [];
    let users = [];

    async function loadBranches() {
      const res = await fetch('/api/org/branches');
      const body = await res.json();
      branches = body.data || [];
      const opts = '<option value="">— No branch —</option>' + branches.map((b) => `<option value="${b.id}">${b.name}</option>`).join('');
      document.getElementById('add-branch').innerHTML = opts;
      document.getElementById('edit-branch').innerHTML = opts;
    }

    async function loadUsers() {
      const res = await fetch('/api/admin/users', { headers: { Authorization: 'Bearer ' + token } });
      const body = await res.json();
      users = body.data || [];
      renderTable();
    }

    function renderTable() {
      const tbody = document.getElementById('tbody');
      if (!users.length) {
        tbody.innerHTML = '<tr><td colspan="5" class="p-6 text-center text-slate-500">No users yet.</td></tr>';
        return;
      }
      tbody.innerHTML = users.map((u) => {
        const branch = branches.find((b) => b.id === u.branch_id);
        const roleBadge = {
          owner: 'bg-purple-100 text-purple-800',
          admin: 'bg-blue-100 text-blue-800',
          manager: 'bg-emerald-100 text-emerald-800',
          supervisor: 'bg-yellow-100 text-yellow-800',
          staff: 'bg-slate-200 text-slate-700',
          customer: 'bg-slate-100 text-slate-600',
        }[u.role] || 'bg-slate-100 text-slate-600';
        return `
          <tr class="border-t border-slate-100 hover:bg-slate-50">
            <td class="p-4 font-medium">${escapeHtml(u.name || '')}</td>
            <td class="p-4 text-slate-600">${escapeHtml(u.email || '')}</td>
            <td class="p-4"><span class="text-xs px-2 py-0.5 rounded-full font-semibold ${roleBadge}">${escapeHtml(u.role || '')}</span></td>
            <td class="p-4 text-slate-600">${branch ? escapeHtml(branch.name) : '—'}</td>
            <td class="p-4 text-right">
              <button data-edit="${escapeHtml(u.id)}" class="text-blue-600 hover:underline text-xs font-medium"><i class="fa-solid fa-pen"></i> Edit</button>
            </td>
          </tr>`;
      }).join('');
      tbody.querySelectorAll('[data-edit]').forEach((b) => {
        b.addEventListener('click', () => openEdit(b.dataset.edit));
      });
    }

    function openEdit(id) {
      const u = users.find((x) => x.id === id);
      if (!u) return;
      const form = document.getElementById('edit-form');
      form.id.value = u.id;
      form.name.value = u.name || '';
      form.role.value = u.role || 'staff';
      form.branch_id.value = u.branch_id || '';
      form.password.value = '';
      document.getElementById('edit-sub').textContent = u.email;
      document.getElementById('edit-err').classList.add('hidden');
      document.getElementById('edit-ok').classList.add('hidden');
      document.getElementById('delete-user-btn').style.display = u.id === user.id ? 'none' : 'block';
      document.getElementById('edit-modal').classList.remove('hidden');
    }

    function closeEdit() {
      document.getElementById('edit-modal').classList.add('hidden');
    }

    function closeAdd() {
      document.getElementById('add-modal').classList.add('hidden');
    }

    document.getElementById('add-btn').addEventListener('click', () => {
      document.getElementById('add-form').reset();
      document.getElementById('add-err').classList.add('hidden');
      document.getElementById('add-modal').classList.remove('hidden');
    });
    document.querySelectorAll('[data-close-add]').forEach((b) => b.addEventListener('click', closeAdd));
    document.querySelectorAll('[data-close-edit]').forEach((b) => b.addEventListener('click', closeEdit));

    document.getElementById('add-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const err = document.getElementById('add-err');
      err.classList.add('hidden');
      const form = e.target;
      const data = {
        name: form.name.value,
        email: form.email.value,
        password: form.password.value,
        role: form.role.value,
        branch_id: form.branch_id.value || null,
      };
      try {
        const res = await fetch('/api/admin/users', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
          body: JSON.stringify(data),
        });
        const body = await res.json();
        if (!res.ok || body.error) throw new Error(body.error?.message || 'Create failed');
        closeAdd();
        loadUsers();
      } catch (e) {
        err.textContent = e.message;
        err.classList.remove('hidden');
      }
    });

    document.getElementById('edit-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const err = document.getElementById('edit-err');
      const ok = document.getElementById('edit-ok');
      err.classList.add('hidden'); ok.classList.add('hidden');
      const form = e.target;
      const id = form.id.value;
      const updates = {
        name: form.name.value,
        role: form.role.value,
        branch_id: form.branch_id.value || null,
      };
      try {
        const res = await fetch('/api/admin/users/' + encodeURIComponent(id), {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
          body: JSON.stringify(updates),
        });
        const body = await res.json();
        if (!res.ok || body.error) throw new Error(body.error?.message || 'Update failed');

        if (form.password.value) {
          if (form.password.value.length < 8) throw new Error('Password must be at least 8 chars');
          const pwRes = await fetch('/api/admin/users/' + encodeURIComponent(id) + '/password', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
            body: JSON.stringify({ password: form.password.value }),
          });
          const pwBody = await pwRes.json();
          if (!pwRes.ok || pwBody.error) throw new Error(pwBody.error?.message || 'Password change failed');
        }

        ok.textContent = 'Changes saved.';
        ok.classList.remove('hidden');
        loadUsers();
        setTimeout(closeEdit, 800);
      } catch (e) {
        err.textContent = e.message;
        err.classList.remove('hidden');
      }
    });

    document.getElementById('delete-user-btn').addEventListener('click', async () => {
      const form = document.getElementById('edit-form');
      const id = form.id.value;
      if (!confirm('Delete this user? Their account will be disabled.')) return;
      try {
        const res = await fetch('/api/admin/users/' + encodeURIComponent(id), {
          method: 'DELETE',
          headers: { Authorization: 'Bearer ' + token },
        });
        const body = await res.json();
        if (!res.ok || body.error) throw new Error(body.error?.message || 'Delete failed');
        closeEdit();
        loadUsers();
      } catch (e) {
        document.getElementById('edit-err').textContent = e.message;
        document.getElementById('edit-err').classList.remove('hidden');
      }
    });

    function escapeHtml(s=''){ return String(s).replace(/[&<>"']/g, (c)=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }

    (async () => {
      await loadBranches();
      await loadUsers();
    })();
  </script>
</body>
</html>
USERSHTML

# =============================================================================
# 5. Update all admin sidebar nav links to include "Users"
# =============================================================================
echo "▶ Adding Users link to admin sidebar nav"
for f in public/admin/index.html public/admin/analytics.html public/admin/best-sellers.html public/admin/branch-assign.html; do
  if [ -f "$f" ] && ! grep -q 'href="/admin/users.html"' "$f"; then
    sed -i 's|<a href="/admin/branch-assign.html"[^<]*</a>|<a href="/admin/branch-assign.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-code-branch w-4"></i> Branch assign</a>\n      <a href="/admin/users.html" class="flex items-center gap-3 px-3 py-2 rounded-md hover:bg-slate-800"><i class="fa-solid fa-user-shield w-4"></i> Users</a>|' "$f"
    echo "  ✓ $f"
  fi
done

# =============================================================================
# Stage
# =============================================================================
echo ""
echo "▶ Staging files…"
git add functions/api/admin/users/index.js
git add 'functions/api/admin/users/[id].js'
git add 'functions/api/admin/users/[id]/password.js'
git add public/admin/users.html
git add public/admin/index.html
git add public/admin/analytics.html
git add public/admin/best-sellers.html
git add public/admin/branch-assign.html

echo ""
echo "▶ Diff summary:"
git status --short

echo ""
echo "✅ Chunk written."
echo ""
echo "Deploy:"
echo "  npx wrangler pages deploy public --project-name u-containers-com --branch main --commit-dirty=true"
echo "  git add -A; git commit -m 'feat: admin user management (add, edit, change password)'; git push origin main"
echo ""
