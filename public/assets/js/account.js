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
