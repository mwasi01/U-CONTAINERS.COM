export async function onRequestGet(ctx) {
  const upgrade = ctx.request.headers.get('Upgrade');
  if (upgrade !== 'websocket') return new Response('Expected websocket', { status: 400 });
  // Minimal echo DO routing stub
  return new Response('WebSocket endpoint — implement DO routing', { status: 501 });
}
