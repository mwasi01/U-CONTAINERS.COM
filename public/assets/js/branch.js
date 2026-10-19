const KEY = 'ngu.branch';
export const setBranch = (slug) => localStorage.setItem(KEY, slug);
export const currentBranch = () => localStorage.getItem(KEY) || 'kikuyu';
document.addEventListener('DOMContentLoaded', () => {
  const body = document.body;
  body.dataset.branch ||= currentBranch();
});
