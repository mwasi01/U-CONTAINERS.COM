import { jsonResponse } from '../../../src/errors.js';
export async function onRequestGet() { return jsonResponse({ products: [], customers: [] }); }
