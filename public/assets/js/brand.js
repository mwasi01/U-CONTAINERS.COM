const CART_KEY = 'ngu.cart.v1';

export function readCart() {
  try { return JSON.parse(localStorage.getItem(CART_KEY)) || []; }
  catch { return []; }
}

export function writeCart(items) {
  localStorage.setItem(CART_KEY, JSON.stringify(items));
  document.dispatchEvent(new CustomEvent('cart:updated', { detail: items }));
}

export function addToCart(product, qty = 1) {
  const items = readCart();
  const existing = items.find((i) => i.id === product.id);
  if (existing) existing.qty += qty;
  else items.push({ id: product.id, name: product.name, price: product.price, image: product.image || '', qty });
  writeCart(items);
}

export function updateQty(id, qty) {
  const items = readCart();
  const item = items.find((i) => i.id === id);
  if (!item) return;
  if (qty <= 0) {
    writeCart(items.filter((i) => i.id !== id));
  } else {
    item.qty = qty;
    writeCart(items);
  }
}

export function removeItem(id) {
  writeCart(readCart().filter((i) => i.id !== id));
}

export function clearCart() {
  writeCart([]);
}

export function cartCount() {
  return readCart().reduce((sum, i) => sum + i.qty, 0);
}

export function cartTotal() {
  return readCart().reduce((sum, i) => sum + i.price * i.qty, 0);
}

function updateCartBadge() {
  const badge = document.getElementById('cart-count');
  if (badge) {
    const n = cartCount();
    badge.textContent = String(n);
    badge.style.display = n > 0 ? 'inline-flex' : 'none';
  }
}

function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach((a) => {
    a.addEventListener('click', (e) => {
      const t = document.querySelector(a.getAttribute('href'));
      if (t) { e.preventDefault(); t.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
    });
  });
}

function initYear() {
  document.querySelectorAll('[data-year]').forEach((el) => { el.textContent = new Date().getFullYear(); });
}

function initMobileMenu() {
  const btn = document.getElementById('menu-btn');
  const menu = document.getElementById('mobile-menu');
  if (btn && menu) btn.addEventListener('click', () => menu.classList.toggle('hidden'));
}

document.addEventListener('DOMContentLoaded', () => {
  updateCartBadge();
  initSmoothScroll();
  initYear();
  initMobileMenu();
  document.addEventListener('cart:updated', updateCartBadge);
});
