import { api } from './api.js';
import { qs } from './utils.js';
document.addEventListener('DOMContentLoaded', async () => {
  const grid = qs('#product-grid');
  if (!grid) return;
  try {
    const products = await api.get('/api/products');
    grid.innerHTML = products.map((p) => `<article><h3>${p.name}</h3><p>${p.price}</p></article>`).join('');
  } catch { grid.textContent = 'Failed to load products.'; }
});
