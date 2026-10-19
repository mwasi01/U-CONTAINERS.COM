export const ROLES = ['owner', 'admin', 'manager', 'supervisor', 'staff', 'customer'];

export function can(user, permission) {
  if (!user) return false;
  if (user.role === 'owner' || user.role === 'admin') return true;
  return (user.permissions || []).includes(permission) || (user.permissions || []).includes('*');
}

export function requireRole(user, ...allowed) {
  if (!user || !allowed.includes(user.role)) {
    const e = new Error(`Requires role: ${allowed.join(', ')}`);
    e.status = 403; throw e;
  }
  return user;
}
