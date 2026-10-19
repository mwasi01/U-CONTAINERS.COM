import { jsonResponse } from '../../../src/errors.js';
export async function onRequestPost() {
  // Always return ok so we don't leak account existence
  return jsonResponse({ ok: true });
}
