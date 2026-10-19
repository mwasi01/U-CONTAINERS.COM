import { db } from './db.js';
export const getOrg = (env) => db(env).first('SELECT * FROM organizations LIMIT 1');
export const listBranches = (env) => db(env).all('SELECT * FROM branches WHERE deleted_at IS NULL ORDER BY name');
