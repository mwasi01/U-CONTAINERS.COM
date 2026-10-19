import { jsonResponse } from '../../../src/errors.js';
export async function onRequestGet() { return jsonResponse({}); }
export async function onRequestPost() { return jsonResponse({ ok: true }); }
