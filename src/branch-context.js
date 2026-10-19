// Resolves which branch a user is allowed to see.
// Owners/admins see all branches. Managers/supervisors/staff see their own branch.
// Returns null when the user has full access (no filter needed).

export function scopedBranchId(user, requestedBranchId) {
  if (!user) return null;

  // Owner and admin can see everything, or filter to a specific branch if requested
  if (user.role === 'owner' || user.role === 'admin') {
    return requestedBranchId || null;
  }

  // Manager / supervisor / staff are locked to their assigned branch
  if (user.branchId) {
    // Ignore any requested branch that differs from their own
    return user.branchId;
  }

  // Fallback: no scope → no filter (shouldn't happen for staff roles)
  return null;
}
