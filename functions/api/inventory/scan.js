import { decodePayload } from '../../../src/barcode.js';
import { jsonResponse } from '../../../src/errors.js';
export async function onRequestPost(ctx) {
  const body = await ctx.request.json().catch(() => null);
  return jsonResponse(decodePayload(body?.code || ''));
}
