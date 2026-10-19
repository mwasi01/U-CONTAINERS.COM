export async function onRequest(ctx) {
  const user = ctx.data?.user;
  if (!user || !['owner', 'admin', 'manager'].includes(user.role)) {
    return new Response('Forbidden', { status: 403 });
  }
  return ctx.next();
}
