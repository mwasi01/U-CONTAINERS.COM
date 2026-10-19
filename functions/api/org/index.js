import { getOrg } from '../../../src/org.js';
import { jsonResponse } from '../../../src/errors.js';
export async function onRequestGet(ctx) { return jsonResponse(await getOrg(ctx.env)); }
