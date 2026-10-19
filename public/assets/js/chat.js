import { api } from './api.js';
export async function loadThread() {
  const root = document.getElementById('chat-thread');
  if (!root) return;
  root.textContent = 'Chat loaded (stub).';
}
document.addEventListener('DOMContentLoaded', loadThread);
