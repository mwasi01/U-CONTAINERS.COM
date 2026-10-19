export async function onRequestPost(ctx) {
  const body = await ctx.request.text();
  console.log('stripe webhook', body.length, 'bytes');
  return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } });
}
