import { uuid, nowISO } from './utils.js';
import { db } from './db.js';
export async function notify(env, { userId, title, body, url }) {
  const d = db(env);
  const id = uuid();
  await d.run(
    `INSERT INTO notifications (id, user_id, title, body, url, created_at) VALUES (?, ?, ?, ?, ?, ?)`,
    id, userId, title, body || null, url || null, nowISO()
  );
  return id;
}
