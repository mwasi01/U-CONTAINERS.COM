import { qs } from './utils.js';
document.addEventListener('DOMContentLoaded', () => {
  const form = qs('#contact-form');
  if (form) {
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      alert('Message sent (stub).');
    });
  }
});
