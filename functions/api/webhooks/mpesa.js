export async function onRequestPost(ctx) {
  const body = await ctx.request.json().catch(() => ({}));
  console.log('mpesa webhook', body);
  return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
}
