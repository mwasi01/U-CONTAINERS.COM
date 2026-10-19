import { db } from '../../../../src/db.js';
import { jsonResponse } from '../../../../src/errors.js';
export async function onRequestGet() { return jsonResponse([]); }
