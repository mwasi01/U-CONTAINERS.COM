import { jsonResponse, badRequest } from '../../src/errors.js';
export async function onRequestPost(ctx) {
  const body = await ctx.request.json().catch(() => null);
  if (!body?.email || !body?.message) throw badRequest('email and message required');
  console.log('contact', body);
  return jsonResponse({ ok: true });
}
