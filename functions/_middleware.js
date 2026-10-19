import { getAuthUser } from '../src/auth.js';
import { corsHeaders } from '../src/cors.js';
import { errorResponse } from '../src/errors.js';

export async function onRequest(ctx) {
  if (ctx.request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders() });
  }
  try {
    ctx.data.user = await getAuthUser(ctx);
    const res = await ctx.next();
    for (const [k, v] of Object.entries(corsHeaders())) res.headers.set(k, v);
    return res;
  } catch (err) {
    console.error('middleware', err);
    return errorResponse(err);
  }
}
