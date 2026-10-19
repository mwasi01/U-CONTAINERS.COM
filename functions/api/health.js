export async function onRequest() {
  return new Response(JSON.stringify({ data: { ok: true, at: new Date().toISOString() }, error: null }), {
    headers: { 'Content-Type': 'application/json' },
  });
}
