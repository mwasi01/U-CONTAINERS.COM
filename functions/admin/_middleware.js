export async function onRequest(ctx) {
  const url = new URL(ctx.request.url);
  // Allow the login page itself (it's a static file — middleware only runs for /functions)
  // If we get here, it means a /api/admin/* call or dynamic route.

  const user = ctx.data?.user;
  if (!user) {
    return new Response(JSON.stringify({ data: null, error: { code: 'unauthorized', message: 'Sign in required' } }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  if (!['owner', 'admin', 'manager'].includes(user.role)) {
    return new Response(JSON.stringify({ data: null, error: { code: 'forbidden', message: 'Admin access only' } }), {
      status: 403,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  return ctx.next();
}
