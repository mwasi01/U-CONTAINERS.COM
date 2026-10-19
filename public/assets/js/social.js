import { api } from './api.js';
export async function loadFeed() {
  const root = document.querySelector('#feed, #index, #explore');
  if (!root) return;
  try {
    const posts = await api.get('/api/social/feed');
    root.innerHTML = posts.map((p) => `<article class="post-card">${p.body || ''}</article>`).join('');
  } catch { root.textContent = 'Failed to load feed.'; }
}
document.addEventListener('DOMContentLoaded', loadFeed);
