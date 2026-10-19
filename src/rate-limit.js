export async function rateLimit(kv, key, limit = 60, windowSec = 60) {
  const bucket = `${key}:${Math.floor(Date.now() / 1000 / windowSec)}`;
  const count = Number((await kv.get(bucket)) || 0);
  if (count >= limit) return { ok: false };
  await kv.put(bucket, String(count + 1), { expirationTtl: windowSec * 2 });
  return { ok: true };
}
