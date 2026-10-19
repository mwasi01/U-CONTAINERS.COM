export function scopeToBranch(user, branchId) {
  if (!user) { const e = new Error('No user'); e.status = 401; throw e; }
  if (user.role === 'owner' || user.role === 'admin') return branchId;
  if (!user.branchId || user.branchId !== branchId) {
    const e = new Error('Branch scope violation'); e.status = 403; throw e;
  }
  return branchId;
}
export function branchFromRequest(ctx) {
  const url = new URL(ctx.request.url);
  return url.searchParams.get('branch') || ctx.request.headers.get('X-Branch') || null;
}
