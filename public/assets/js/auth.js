import { api } from './api.js';
import { qs } from './utils.js';
document.addEventListener('DOMContentLoaded', () => {
  const login = qs('#login-form');
  login?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = Object.fromEntries(new FormData(login));
    const res = await api.post('/api/auth/login', data);
    if (res.error) alert(res.error.message);
    else location.href = '/account/';
  });
});
