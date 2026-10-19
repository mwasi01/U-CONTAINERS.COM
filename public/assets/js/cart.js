const KEY = 'ngu.cart';
export const readCart = () => JSON.parse(localStorage.getItem(KEY) || '[]');
export const writeCart = (items) => localStorage.setItem(KEY, JSON.stringify(items));
export function addToCart(product, qty = 1) {
  const items = readCart();
  const ex = items.find((i) => i.id === product.id);
  if (ex) ex.qty += qty; else items.push({ ...product, qty });
  writeCart(items);
}
document.addEventListener('DOMContentLoaded', () => {
  const root = document.getElementById('cart-items');
  if (!root) return;
  const items = readCart();
  root.textContent = items.length ? items.map((i) => `${i.name} × ${i.qty}`).join(', ') : 'Cart empty';
});
