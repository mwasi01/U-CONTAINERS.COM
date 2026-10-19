export function db(env) {
  if (!env?.DB) throw new Error('D1 binding DB missing');
  return {
    all:   (sql, ...p) => env.DB.prepare(sql).bind(...p).all().then((r) => r.results || []),
    first: (sql, ...p) => env.DB.prepare(sql).bind(...p).first(),
    run:   (sql, ...p) => env.DB.prepare(sql).bind(...p).run(),
  };
}
