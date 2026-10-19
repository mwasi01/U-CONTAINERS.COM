#!/usr/bin/env bash
# chunk4.sh — auth pages, account dashboard, account pages, account.js
set -euo pipefail
cd "$(dirname "$0")"
echo "▶ Repo root: $(pwd)"

test -d public   || { echo "FATAL: public/ missing"; exit 1; }
test -d functions || { echo "FATAL: functions/ missing"; exit 1; }

mkdir -p public/auth public/account public/assets/js

# =============================================================================
# 1. account.js — shared helper (JWT storage, auth guard, fetch helper)
# =============================================================================
echo "▶ Writing public/assets/js/account.js"
cat > public/assets/js/account.js <<'ACCOUNTJS'
// NEVER GIVE UP ENTERPRISE — account helpers.
// Stores JWT in localStorage, wraps fetch with Authorization header,
// redirects to /auth/login when not authenticated.

const TOKEN_KEY = 'ngu.token';
const USER_KEY = 'ngu.user';

export function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

export function getUser() {
  try { return JSON.parse(localStorage.getItem(USER_KEY) || 'null'); }
  catch { return null; }
}

export function saveSession(token, user) {
  localStorage.setItem(TOKEN_KEY, token);
  if (user) localStorage.setItem(USER_KEY, JSON.stringify(user));
}

export function clearSession() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
}

export async function apiFetch(path, opts = {}) {
  const token = getToken();
  const headers = {
    'Content-Type': 'application/json',
    ...(opts.headers || {}),
  };
  if (token) headers['Authorization'] = 'Bearer ' + token;
  const res = await fetch(path, { ...opts, headers });
  const body = await res.json().catch(() => null);
  if (!res.ok) {
    const err = new Error(body?.error?.message || res.statusText);
    err.status = res.status;
    err.body = body;
    if (res.status === 401 && !path.includes('/auth/')) {
      clearSession();
      location.href = '/auth/login.html?next=' + encodeURIComponent(location.pathname);
      throw err;
    }
    throw err;
  }
  return body?.data ?? body;
}

export async function requireAuth() {
  const token = getToken();
  if (!token) {
    location.href = '/auth/login.html?next=' + encodeURIComponent(location.pathname);
    return null;
  }
  try {
    const user = await apiFetch('/api/auth/me');
    if (!user) throw new Error('no user');
    return user;
  } catch {
    clearSession();
    location.href = '/auth/login.html?next=' + encodeURIComponent(location.pathname);
    return null;
  }
}

export async function logout() {
  try { await apiFetch('/api/auth/logout', { method: 'POST' }); }
  catch {}
  clearSession();
  location.href = '/';
}

// Wire the header's "Account" link based on login state.
document.addEventListener('DOMContentLoaded', () => {
  const user = getUser();
  document.querySelectorAll('[data-account-link]').forEach((el) => {
    if (user) {
      el.textContent = user.name ? user.name.split(' ')[0] : 'Account';
      el.href = '/account/';
    } else {
      el.textContent = 'Sign in';
      el.href = '/auth/login.html';
    }
  });
});
ACCOUNTJS

# =============================================================================
# 2. Shared head/footer (same branding as the rest of the site)
# =============================================================================
HEAD_HTML='<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>__TITLE__ · NEVER GIVE UP ENTERPRISE</title>
  <link rel="icon" href="/assets/images/favicon.ico" />
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />
  <script>
    tailwind.config = { theme: { extend: { fontFamily: { sans: ["Inter","system-ui","sans-serif"] }, colors: { brand: { 500:"#3b82f6",600:"#2563eb",700:"#1d4ed8" }, leaf: { 500:"#10b981",600:"#059669" } } } } };
  </script>
</head>
<body class="font-sans bg-slate-50 text-slate-800 flex flex-col min-h-screen">
  <header class="bg-white shadow-sm sticky top-0 z-50">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex justify-between h-16 items-center">
      <a href="/" class="flex items-center gap-3">
        <span class="h-10 w-10 rounded-full bg-gradient-to-r from-brand-500 to-leaf-500 text-white font-extrabold flex items-center justify-center text-sm">NGU</span>
        <span class="hidden sm:block leading-tight"><span class="block text-sm font-extrabold">NEVER GIVE UP</span><span class="block text-[11px] text-slate-500 tracking-widest">ENTERPRISE</span></span>
      </a>
      <nav class="hidden md:flex gap-6 text-sm font-medium">
        <a href="/products/" class="hover:text-brand-600">Products</a>
        <a href="/branches/" class="hover:text-brand-600">Branches</a>
        <a href="/about.html" class="hover:text-brand-600">About</a>
        <a href="/contact.html" class="hover:text-brand-600">Contact</a>
      </nav>
      <div class="flex items-center gap-3">
        <a href="/cart/" class="relative p-2"><i class="fa-solid fa-cart-shopping text-lg"></i><span id="cart-count" class="absolute -top-1 -right-1 bg-brand-600 text-white text-[10px] font-bold h-5 min-w-[20px] px-1 rounded-full flex items-center justify-center" style="display:none;">0</span></a>
        <a href="/account/" data-account-link class="text-sm font-medium text-slate-700 hover:text-brand-600">Sign in</a>
      </div>
    </div>
  </header>
  <main class="flex-1">'

FOOT_HTML='  </main>
  <footer class="bg-slate-900 text-slate-400 pt-10 pb-6 px-4 sm:px-6 lg:px-8 text-sm">
    <div class="max-w-7xl mx-auto text-center">
      <p>&copy; <span data-year>2026</span> NEVER GIVE UP ENTERPRISE · <a href="tel:+254704787011" class="hover:text-white">+254 704 787 011</a> · <a href="mailto:nopgiveup@gmail.com" class="hover:text-white">nopgiveup@gmail.com</a></p>
    </div>
  </footer>
  <script type="module">
    import { } from "/assets/js/brand.js";
    import "/assets/js/account.js";
  </script>
</body>
</html>'

write_page() {
  local path="$1"
  local title="$2"
  local body
  body="$(cat)"
  mkdir -p "$(dirname "$path")"
  {
    printf '%s\n' "${HEAD_HTML/__TITLE__/$title}"
    printf '%s\n' "$body"
    printf '%s\n' "$FOOT_HTML"
  } > "$path"
}

# =============================================================================
# 3. AUTH — login
# =============================================================================
echo "▶ Writing public/auth/login.html"
write_page "public/auth/login.html" "Sign in" <<'BODY'
  <section class="py-16 px-4 sm:px-6 lg:px-8 bg-white">
    <div class="max-w-md mx-auto bg-white rounded-2xl shadow-sm ring-1 ring-slate-100 p-8">
      <h1 class="text-2xl font-extrabold text-center">Sign in</h1>
      <p class="mt-1 text-center text-sm text-slate-500">Welcome back to NEVER GIVE UP ENTERPRISE.</p>
      <div id="err" class="hidden mt-4 p-3 rounded-md bg-red-50 border border-red-200 text-red-700 text-sm"></div>
      <form id="login-form" class="mt-6 space-y-4">
        <div>
          <label class="text-sm font-medium">Email</label>
          <input name="email" type="email" required autocomplete="email" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-brand-500" />
        </div>
        <div>
          <label class="text-sm font-medium">Password</label>
          <input name="password" type="password" required autocomplete="current-password" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-brand-500" />
        </div>
        <button type="submit" class="w-full inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-md bg-brand-600 text-white font-semibold hover:bg-brand-700">
          <i class="fa-solid fa-arrow-right-to-bracket"></i> Sign in
        </button>
      </form>
      <div class="mt-6 text-center text-sm text-slate-500">
        <a href="/auth/forgot-password.html" class="hover:text-brand-600">Forgot your password?</a>
        <div class="mt-2">No account? <a href="/auth/register.html" class="text-brand-600 font-semibold hover:underline">Create one</a></div>
      </div>
    </div>
  </section>
  <script type="module">
    import { saveSession } from '/assets/js/account.js';
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
        saveSession(body.data.token, body.data.user);
        const next = new URLSearchParams(location.search).get('next') || '/account/';
        location.href = next;
      } catch (e) {
        err.textContent = e.message;
        err.classList.remove('hidden');
      }
    });
  </script>
BODY

# =============================================================================
# 4. AUTH — register
# =============================================================================
echo "▶ Writing public/auth/register.html"
write_page "public/auth/register.html" "Create account" <<'BODY'
  <section class="py-16 px-4 sm:px-6 lg:px-8 bg-white">
    <div class="max-w-md mx-auto bg-white rounded-2xl shadow-sm ring-1 ring-slate-100 p-8">
      <h1 class="text-2xl font-extrabold text-center">Create your account</h1>
      <p class="mt-1 text-center text-sm text-slate-500">Track orders and reorder in a click.</p>
      <div id="err" class="hidden mt-4 p-3 rounded-md bg-red-50 border border-red-200 text-red-700 text-sm"></div>
      <form id="register-form" class="mt-6 space-y-4">
        <div>
          <label class="text-sm font-medium">Full name</label>
          <input name="name" required autocomplete="name" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-brand-500" />
        </div>
        <div>
          <label class="text-sm font-medium">Email</label>
          <input name="email" type="email" required autocomplete="email" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-brand-500" />
        </div>
        <div>
          <label class="text-sm font-medium">Phone (optional)</label>
          <input name="phone" autocomplete="tel" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-brand-500" />
        </div>
        <div>
          <label class="text-sm font-medium">Password</label>
          <input name="password" type="password" required minlength="8" autocomplete="new-password" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-brand-500" />
          <p class="mt-1 text-xs text-slate-500">At least 8 characters.</p>
        </div>
        <button type="submit" class="w-full inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-md bg-brand-600 text-white font-semibold hover:bg-brand-700">
          <i class="fa-solid fa-user-plus"></i> Create account
        </button>
      </form>
      <div class="mt-6 text-center text-sm text-slate-500">
        Already have an account? <a href="/auth/login.html" class="text-brand-600 font-semibold hover:underline">Sign in</a>
      </div>
    </div>
  </section>
  <script type="module">
    import { saveSession } from '/assets/js/account.js';
    const form = document.getElementById('register-form');
    const err = document.getElementById('err');
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      err.classList.add('hidden');
      const data = Object.fromEntries(new FormData(form));
      try {
        const res = await fetch('/api/auth/register', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(data),
        });
        const body = await res.json();
        if (!res.ok || body.error) throw new Error(body.error?.message || 'Could not register');
        saveSession(body.data.token, body.data.user);
        location.href = '/account/';
      } catch (e) {
        err.textContent = e.message;
        err.classList.remove('hidden');
      }
    });
  </script>
BODY

# =============================================================================
# 5. AUTH — forgot password
# =============================================================================
echo "▶ Writing public/auth/forgot-password.html"
write_page "public/auth/forgot-password.html" "Forgot password" <<'BODY'
  <section class="py-16 px-4 sm:px-6 lg:px-8 bg-white">
    <div class="max-w-md mx-auto bg-white rounded-2xl shadow-sm ring-1 ring-slate-100 p-8">
      <h1 class="text-2xl font-extrabold text-center">Forgot password</h1>
      <p class="mt-1 text-center text-sm text-slate-500">Enter your email and we'll send a reset link.</p>
      <div id="ok" class="hidden mt-4 p-3 rounded-md bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm"></div>
      <form id="forgot-form" class="mt-6 space-y-4">
        <div>
          <label class="text-sm font-medium">Email</label>
          <input name="email" type="email" required autocomplete="email" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-brand-500" />
        </div>
        <button type="submit" class="w-full inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-md bg-brand-600 text-white font-semibold hover:bg-brand-700">
          <i class="fa-regular fa-paper-plane"></i> Send reset link
        </button>
      </form>
      <div class="mt-6 text-center text-sm text-slate-500">
        <a href="/auth/login.html" class="hover:text-brand-600">Back to sign in</a>
      </div>
    </div>
  </section>
  <script type="module">
    const form = document.getElementById('forgot-form');
    const ok = document.getElementById('ok');
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const data = Object.fromEntries(new FormData(form));
      try {
        await fetch('/api/auth/forgot-password', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(data),
        });
      } catch {}
      ok.textContent = "If that email is registered, you'll receive a reset link shortly.";
      ok.classList.remove('hidden');
      form.reset();
    });
  </script>
BODY

# =============================================================================
# 6. AUTH — reset password
# =============================================================================
echo "▶ Writing public/auth/reset-password.html"
write_page "public/auth/reset-password.html" "Reset password" <<'BODY'
  <section class="py-16 px-4 sm:px-6 lg:px-8 bg-white">
    <div class="max-w-md mx-auto bg-white rounded-2xl shadow-sm ring-1 ring-slate-100 p-8">
      <h1 class="text-2xl font-extrabold text-center">Reset your password</h1>
      <div id="err" class="hidden mt-4 p-3 rounded-md bg-red-50 border border-red-200 text-red-700 text-sm"></div>
      <form id="reset-form" class="mt-6 space-y-4">
        <div>
          <label class="text-sm font-medium">New password</label>
          <input name="password" type="password" required minlength="8" autocomplete="new-password" class="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-brand-500" />
        </div>
        <button type="submit" class="w-full inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-md bg-brand-600 text-white font-semibold hover:bg-brand-700">
          <i class="fa-solid fa-lock"></i> Reset password
        </button>
      </form>
      <div class="mt-6 text-center text-sm text-slate-500">
        <a href="/auth/login.html" class="hover:text-brand-600">Back to sign in</a>
      </div>
    </div>
  </section>
  <script type="module">
    const form = document.getElementById('reset-form');
    const err = document.getElementById('err');
    const token = new URLSearchParams(location.search).get('token') || '';
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      err.classList.add('hidden');
      const { password } = Object.fromEntries(new FormData(form));
      try {
        const res = await fetch('/api/auth/reset-password', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ token, password }),
        });
        const body = await res.json();
        if (!res.ok || body.error) throw new Error(body.error?.message || 'Could not reset');
        location.href = '/auth/login.html';
      } catch (e) {
        err.textContent = e.message;
        err.classList.remove('hidden');
      }
    });
  </script>
BODY

# =============================================================================
# 7. ACCOUNT — dashboard
# =============================================================================
echo "▶ Writing public/account/index.html"
write_page "public/account/index.html" "My Account" <<'BODY'
  <section class="py-10 px-4 sm:px-6 lg:px-8">
    <div class="max-w-6xl mx-auto">
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 class="text-3xl font-extrabold" id="greeting">Welcome</h1>
          <p class="text-slate-500 mt-1" id="subgreeting">Loading your account…</p>
        </div>
        <button id="logout-btn" class="inline-flex items-center gap-2 px-4 py-2 rounded-md bg-white ring-1 ring-slate-200 text-sm font-medium hover:ring-red-300 hover:text-red-600">
          <i class="fa-solid fa-arrow-right-from-bracket"></i> Sign out
        </button>
      </div>

      <div class="mt-8 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <a href="/account/orders.html" class="bg-white rounded-xl ring-1 ring-slate-100 p-5 hover:ring-brand-300">
          <i class="fa-solid fa-box text-2xl text-brand-600"></i>
          <h3 class="mt-3 font-bold">My orders</h3>
          <p class="text-sm text-slate-500 mt-1" id="stat-orders">—</p>
        </a>
        <a href="/account/messages.html" class="bg-white rounded-xl ring-1 ring-slate-100 p-5 hover:ring-brand-300">
          <i class="fa-regular fa-message text-2xl text-brand-600"></i>
          <h3 class="mt-3 font-bold">Messages</h3>
          <p class="text-sm text-slate-500 mt-1">Chat with our team</p>
        </a>
        <a href="/account/addresses.html" class="bg-white rounded-xl ring-1 ring-slate-100 p-5 hover:ring-brand-300">
          <i class="fa-solid fa-location-dot text-2xl text-brand-600"></i>
          <h3 class="mt-3 font-bold">Addresses</h3>
          <p class="text-sm text-slate-500 mt-1">Manage delivery addresses</p>
        </a>
        <a href="/account/settings.html" class="bg-white rounded-xl ring-1 ring-slate-100 p-5 hover:ring-brand-300">
          <i class="fa-solid fa-gear text-2xl text-brand-600"></i>
          <h3 class="mt-3 font-bold">Settings</h3>
          <p class="text-sm text-slate-500 mt-1">Account preferences</p>
        </a>
      </div>

      <div class="mt-10 bg-white rounded-2xl ring-1 ring-slate-100 p-6">
        <div class="flex items-center justify-between">
          <h2 class="text-lg font-bold">Recent orders</h2>
          <a href="/account/orders.html" class="text-sm text-brand-600 hover:underline">View all →</a>
        </div>
        <div id="recent-orders" class="mt-4"><p class="text-sm text-slate-500">Loading…</p></div>
      </div>
    </div>
  </section>
  <script type="module">
    import { requireAuth, apiFetch, getUser, logout } from '/assets/js/account.js';
    document.getElementById('logout-btn').addEventListener('click', logout);

    (async () => {
      const user = await requireAuth();
      if (!user) return;
      const name = user.name ? user.name.split(' ')[0] : (user.email || 'friend');
      document.getElementById('greeting').textContent = 'Welcome, ' + name + ' 👋';
      document.getElementById('subgreeting').textContent = 'Signed in as ' + (user.email || '');

      try {
        const orders = await apiFetch('/api/orders');
        const list = Array.isArray(orders) ? orders : (orders?.data || []);
        document.getElementById('stat-orders').textContent = list.length + ' order' + (list.length === 1 ? '' : 's');
        const root = document.getElementById('recent-orders');
        if (!list.length) {
          root.innerHTML = '<p class="text-sm text-slate-500">No orders yet. <a class="text-brand-600 hover:underline" href="/products/">Browse products →</a></p>';
          return;
        }
        root.innerHTML = list.slice(0, 5).map((o) => `
          <a href="/account/order.html?id=${encodeURIComponent(o.id)}" class="flex items-center justify-between py-3 border-b border-slate-100 last:border-0 hover:bg-slate-50">
            <div>
              <div class="font-medium">Order #${String(o.id).slice(0, 8)}</div>
              <div class="text-xs text-slate-500">${o.created_at || ''}</div>
            </div>
            <div class="text-right">
              <div class="font-semibold">KES ${Number(o.total || 0).toLocaleString()}</div>
              <span class="text-xs px-2 py-0.5 rounded-full ${o.status === 'pending' ? 'bg-yellow-100 text-yellow-800' : 'bg-emerald-100 text-emerald-800'}">${o.status || 'pending'}</span>
            </div>
          </a>`).join('');
      } catch {
        document.getElementById('recent-orders').innerHTML = '<p class="text-sm text-slate-500">Could not load orders.</p>';
      }
    })();
  </script>
BODY

# =============================================================================
# 8. ACCOUNT — orders list
# =============================================================================
echo "▶ Writing public/account/orders.html"
write_page "public/account/orders.html" "My Orders" <<'BODY'
  <section class="py-10 px-4 sm:px-6 lg:px-8">
    <div class="max-w-4xl mx-auto">
      <nav class="text-sm text-slate-500 mb-4"><a href="/account/" class="hover:text-brand-600">Account</a> / <span class="text-slate-800">Orders</span></nav>
      <h1 class="text-3xl font-extrabold">My orders</h1>
      <p class="text-slate-500 mt-1">Track your purchases from NEVER GIVE UP ENTERPRISE.</p>
      <div id="orders" class="mt-8"><p class="text-slate-500">Loading…</p></div>
    </div>
  </section>
  <script type="module">
    import { requireAuth, apiFetch } from '/assets/js/account.js';
    (async () => {
      const user = await requireAuth();
      if (!user) return;
      try {
        const payload = await apiFetch('/api/orders');
        const orders = Array.isArray(payload) ? payload : (payload?.data || []);
        const root = document.getElementById('orders');
        if (!orders.length) {
          root.innerHTML = '<div class="bg-white rounded-2xl ring-1 ring-slate-100 p-10 text-center"><i class="fa-solid fa-box-open text-4xl text-slate-300"></i><p class="mt-4 font-semibold">No orders yet</p><p class="text-sm text-slate-500 mt-1">Browse our products and place your first order.</p><a href="/products/" class="mt-4 inline-flex items-center gap-2 px-5 py-2 rounded-md bg-brand-600 text-white font-semibold hover:bg-brand-700">Shop products</a></div>';
          return;
        }
        root.innerHTML = '<div class="bg-white rounded-2xl ring-1 ring-slate-100 divide-y divide-slate-100">' + orders.map((o) => `
          <a href="/account/order.html?id=${encodeURIComponent(o.id)}" class="flex items-center justify-between p-5 hover:bg-slate-50">
            <div>
              <div class="font-semibold">Order #${String(o.id).slice(0,8)}</div>
              <div class="text-xs text-slate-500">${o.created_at || ''}</div>
            </div>
            <div class="text-right">
              <div class="font-semibold">KES ${Number(o.total||0).toLocaleString()}</div>
              <span class="text-xs px-2 py-0.5 rounded-full ${o.status === 'pending' ? 'bg-yellow-100 text-yellow-800' : 'bg-emerald-100 text-emerald-800'}">${o.status||'pending'}</span>
            </div>
          </a>`).join('') + '</div>';
      } catch (e) {
        document.getElementById('orders').innerHTML = '<p class="text-red-600">Could not load orders: ' + e.message + '</p>';
      }
    })();
  </script>
BODY

# =============================================================================
# 9. ACCOUNT — single order detail
# =============================================================================
echo "▶ Writing public/account/order.html"
write_page "public/account/order.html" "Order" <<'BODY'
  <section class="py-10 px-4 sm:px-6 lg:px-8">
    <div class="max-w-4xl mx-auto">
      <nav class="text-sm text-slate-500 mb-4"><a href="/account/" class="hover:text-brand-600">Account</a> / <a href="/account/orders.html" class="hover:text-brand-600">Orders</a> / <span class="text-slate-800">Detail</span></nav>
      <div id="order-detail"><p class="text-slate-500">Loading…</p></div>
    </div>
  </section>
  <script type="module">
    import { requireAuth, apiFetch } from '/assets/js/account.js';
    (async () => {
      const user = await requireAuth();
      if (!user) return;
      const id = new URLSearchParams(location.search).get('id');
      const root = document.getElementById('order-detail');
      if (!id) { root.innerHTML = '<p class="text-red-600">Missing order id.</p>'; return; }
      try {
        const order = await apiFetch('/api/orders/' + encodeURIComponent(id));
        const items = order.items || order.order_items || [];
        root.innerHTML = `
          <div class="bg-white rounded-2xl ring-1 ring-slate-100 p-6">
            <div class="flex justify-between items-start">
              <div>
                <h1 class="text-2xl font-extrabold">Order #${String(order.id).slice(0,8)}</h1>
                <p class="text-sm text-slate-500 mt-1">${order.created_at || ''}</p>
              </div>
              <span class="text-sm px-3 py-1 rounded-full ${order.status === 'pending' ? 'bg-yellow-100 text-yellow-800' : 'bg-emerald-100 text-emerald-800'}">${order.status || 'pending'}</span>
            </div>
            <div class="mt-6">
              <h2 class="font-bold">Items</h2>
              <div class="mt-3 divide-y divide-slate-100">
                ${items.length ? items.map((i) => `
                  <div class="flex justify-between py-3">
                    <div><div class="font-medium">${i.name || i.product_name || 'Item'}</div><div class="text-xs text-slate-500">Qty ${i.qty || i.quantity || 1}</div></div>
                    <div class="font-semibold">KES ${Number(i.price || 0).toLocaleString()}</div>
                  </div>`).join('') : '<p class="text-sm text-slate-500">No items in this order.</p>'}
              </div>
            </div>
            <div class="mt-6 border-t border-slate-200 pt-4 flex justify-between text-lg font-extrabold">
              <span>Total</span>
              <span class="text-brand-600">KES ${Number(order.total || 0).toLocaleString()}</span>
            </div>
            <div class="mt-6">
              <a href="https://wa.me/254721200637?text=${encodeURIComponent('Hi, I have a question about order #' + String(order.id).slice(0,8))}" target="_blank" class="inline-flex items-center gap-2 px-4 py-2 rounded-md bg-leaf-500 text-white font-semibold hover:bg-leaf-600">
                <i class="fa-brands fa-whatsapp"></i> Ask about this order
              </a>
            </div>
          </div>
        `;
      } catch (e) {
        root.innerHTML = '<p class="text-red-600">Could not load order: ' + e.message + '</p>';
      }
    })();
  </script>
BODY

# =============================================================================
# 10. ACCOUNT — messages, addresses, wishlist, settings (shells)
# =============================================================================
echo "▶ Writing public/account/messages.html"
write_page "public/account/messages.html" "Messages" <<'BODY'
  <section class="py-10 px-4 sm:px-6 lg:px-8">
    <div class="max-w-3xl mx-auto">
      <nav class="text-sm text-slate-500 mb-4"><a href="/account/" class="hover:text-brand-600">Account</a> / <span class="text-slate-800">Messages</span></nav>
      <h1 class="text-3xl font-extrabold">Messages</h1>
      <p class="text-slate-500 mt-1">Chat with our team about your order or products.</p>
      <div class="mt-8 bg-white rounded-2xl ring-1 ring-slate-100 p-6">
        <p class="text-sm text-slate-600">Message threads will appear here. In the meantime:</p>
        <div class="mt-4 flex flex-col sm:flex-row gap-3">
          <a href="https://wa.me/254721200637" target="_blank" class="inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-md bg-leaf-500 text-white font-semibold hover:bg-leaf-600"><i class="fa-brands fa-whatsapp"></i> WhatsApp us</a>
          <a href="/contact.html" class="inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-md bg-white text-slate-800 font-semibold ring-1 ring-slate-200 hover:ring-brand-300"><i class="fa-regular fa-message"></i> Contact form</a>
          <a href="tel:+254704787011" class="inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-md bg-white text-slate-800 font-semibold ring-1 ring-slate-200 hover:ring-brand-300"><i class="fa-solid fa-phone"></i> Call us</a>
        </div>
      </div>
    </div>
  </section>
BODY

echo "▶ Writing public/account/addresses.html"
write_page "public/account/addresses.html" "Addresses" <<'BODY'
  <section class="py-10 px-4 sm:px-6 lg:px-8">
    <div class="max-w-3xl mx-auto">
      <nav class="text-sm text-slate-500 mb-4"><a href="/account/" class="hover:text-brand-600">Account</a> / <span class="text-slate-800">Addresses</span></nav>
      <div class="flex justify-between items-center">
        <h1 class="text-3xl font-extrabold">Addresses</h1>
      </div>
      <div class="mt-8 bg-white rounded-2xl ring-1 ring-slate-100 p-6">
        <p class="text-sm text-slate-600">Saved delivery addresses will appear here. For now, use the delivery address field at checkout — your next order will save it.</p>
        <a href="/products/" class="mt-4 inline-flex items-center gap-2 px-5 py-2 rounded-md bg-brand-600 text-white font-semibold hover:bg-brand-700">Browse products</a>
      </div>
    </div>
  </section>
BODY

echo "▶ Writing public/account/wishlist.html"
write_page "public/account/wishlist.html" "Wishlist" <<'BODY'
  <section class="py-10 px-4 sm:px-6 lg:px-8">
    <div class="max-w-3xl mx-auto">
      <nav class="text-sm text-slate-500 mb-4"><a href="/account/" class="hover:text-brand-600">Account</a> / <span class="text-slate-800">Wishlist</span></nav>
      <h1 class="text-3xl font-extrabold">Wishlist</h1>
      <div class="mt-8 bg-white rounded-2xl ring-1 ring-slate-100 p-10 text-center">
        <i class="fa-regular fa-heart text-4xl text-slate-300"></i>
        <p class="mt-4 font-semibold">Your wishlist is empty</p>
        <p class="text-sm text-slate-500 mt-1">Save products you love for later.</p>
        <a href="/products/" class="mt-4 inline-flex items-center gap-2 px-5 py-2 rounded-md bg-brand-600 text-white font-semibold hover:bg-brand-700">Browse products</a>
      </div>
    </div>
  </section>
BODY

echo "▶ Writing public/account/settings.html"
write_page "public/account/settings.html" "Settings" <<'BODY'
  <section class="py-10 px-4 sm:px-6 lg:px-8">
    <div class="max-w-3xl mx-auto">
      <nav class="text-sm text-slate-500 mb-4"><a href="/account/" class="hover:text-brand-600">Account</a> / <span class="text-slate-800">Settings</span></nav>
      <h1 class="text-3xl font-extrabold">Account settings</h1>
      <div id="settings-body" class="mt-8 bg-white rounded-2xl ring-1 ring-slate-100 p-6"><p class="text-slate-500">Loading…</p></div>
    </div>
  </section>
  <script type="module">
    import { requireAuth } from '/assets/js/account.js';
    (async () => {
      const user = await requireAuth();
      if (!user) return;
      document.getElementById('settings-body').innerHTML = `
        <div class="space-y-4">
          <div><div class="text-xs uppercase tracking-widest text-slate-500">Name</div><div class="font-medium">${user.name || '—'}</div></div>
          <div><div class="text-xs uppercase tracking-widest text-slate-500">Email</div><div class="font-medium">${user.email || '—'}</div></div>
          <div><div class="text-xs uppercase tracking-widest text-slate-500">Role</div><div class="font-medium capitalize">${user.role || 'customer'}</div></div>
          <div class="pt-4 border-t border-slate-200">
            <p class="text-sm text-slate-500">To change your password, use the reset link from the sign-in page.</p>
            <a href="/auth/forgot-password.html" class="mt-2 inline-flex items-center gap-2 text-brand-600 font-semibold hover:underline">Reset password</a>
          </div>
        </div>
      `;
    })();
  </script>
BODY

# =============================================================================
# 11. Summary
# =============================================================================
echo ""
echo "▶ Staging files…"
git add public/auth/ public/account/ public/assets/js/account.js

echo ""
echo "▶ Diff summary:"
git status --short

echo ""
echo "✅ Chunk 4 written."
echo ""
echo "Next (PowerShell):"
echo "  cd C:\\Users\\hp\\Desktop\\repo-tmp"
echo "  npx wrangler pages deploy public --project-name u-containers-com --branch main"
echo "  git add -A && git commit -m \"feat: auth pages and account dashboard\" && git push origin main"
echo ""
