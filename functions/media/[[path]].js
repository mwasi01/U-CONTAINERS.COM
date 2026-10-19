export async function onRequestGet(ctx) {
  const path = ctx.params.path?.join('/') || '';
  const obj = await ctx.env.MEDIA.get(path);
  if (!obj) return new Response('Not found', { status: 404 });
  const headers = new Headers();
  obj.writeHttpMetadata(headers);
  headers.set('etag', obj.httpEtag);
  headers.set('Cache-Control', 'public, max-age=31536000, immutable');
  return new Response(obj.body, { headers });
}
