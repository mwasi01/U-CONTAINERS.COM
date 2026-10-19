import { jsonResponse } from '../../../src/errors.js';
export async function onRequestGet(ctx) {
  return jsonResponse(ctx.data.user || null);
}
