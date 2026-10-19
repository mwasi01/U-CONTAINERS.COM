export const qs = (s, r = document) => r.querySelector(s);
export const qsa = (s, r = document) => [...r.querySelectorAll(s)];
export const fmtCurrency = (n, c = 'KES') => new Intl.NumberFormat('en-KE', { style: 'currency', currency: c }).format(n);
