export function paginate(url, defaults = { limit: 20, max: 100 }) {
  const p = new URL(url).searchParams;
  const limit  = Math.min(Number(p.get('limit')  || defaults.limit), defaults.max);
  const offset = Math.max(Number(p.get('offset') || 0), 0);
  return { limit, offset };
}
