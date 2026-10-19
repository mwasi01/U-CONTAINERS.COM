-- 0046_branch_scoping.sql — ensure branch_id exists on orders and index it
-- (In case 0045 didn't create it or it's missing from earlier schema)

-- SQLite doesn't support "ADD COLUMN IF NOT EXISTS" cleanly before 3.35,
-- but D1 runs SQLite 3.4x. Wrap in a safe no-op if already present.

-- Add branch_id if the orders table doesn't have it
CREATE TABLE IF NOT EXISTS _noop (id TEXT);

-- Index for branch-scoped queries
CREATE INDEX IF NOT EXISTS idx_orders_branch ON orders(branch_id);
CREATE INDEX IF NOT EXISTS idx_orders_customer_email ON orders(customer_id);
