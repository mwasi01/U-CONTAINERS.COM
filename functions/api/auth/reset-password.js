import { jsonResponse, badRequest } from '../../../src/errors.js';
export async function onRequestPost(ctx) {
  const body = await ctx.request.json().catch(() => null);
  if (!body?.token || !body?.password) throw badRequest('token and password required');
  return jsonResponse({ ok: true });
}
