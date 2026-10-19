import { db } from '../../src/db.js';
import { uuid, nowISO } from '../../src/utils.js';
import { jsonResponse, badRequest, serverError } from '../../src/errors.js';

export async function onRequestPost(ctx) {
  const body = await ctx.request.json().catch(() => null);
  if (!body) throw badRequest('Invalid JSON');
  const { name, email, phone, subject, message } = body;
  if (!name || !email || !message) throw badRequest('name, email, and message are required');
  if (typeof message !== 'string' || message.length < 5) throw badRequest('Message too short');
  try {
    const d = db(ctx.env);
    const id = uuid();
    await d.run(
      `INSERT INTO contact_messages (id, name, email, phone, subject, message, status, created_at)
       VALUES (?, ?, ?, ?, ?, ?, 'new', ?)`,
      id, String(name), String(email), phone ? String(phone) : null,
      subject ? String(subject) : null, String(message), nowISO()
    );
    return jsonResponse({ ok: true, id });
  } catch (err) {
    console.error('contact insert failed', err);
    throw serverError('Could not save message');
  }
}

export async function onRequestGet() {
  return jsonResponse({ ok: true });
}
