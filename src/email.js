export async function sendEmail(env, { to, subject, html }) {
  if (!env.RESEND_API_KEY) { console.warn('RESEND_API_KEY missing — skipping email'); return { skipped: true }; }
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from: env.EMAIL_FROM || 'noreply@example.com', to, subject, html }),
  });
  return res.json();
}
