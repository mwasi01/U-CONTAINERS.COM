import { ROLES } from '../../../src/rbac.js';
import { jsonResponse } from '../../../src/errors.js';
export async function onRequestGet() { return jsonResponse(ROLES); }
