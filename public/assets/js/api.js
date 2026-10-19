export const api = {
  get: (p) => fetch(p).then((r) => r.json()).then((j) => j.data),
  post: (p, b) => fetch(p, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(b),
  }).then((r) => r.json()),
};
