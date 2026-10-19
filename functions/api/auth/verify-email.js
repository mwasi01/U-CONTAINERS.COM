import { jsonResponse } from '../../../src/errors.js';
export async function onRequestGet() { return jsonResponse({ ok: true }); }
