CREATE TABLE orders (
  id          TEXT PRIMARY KEY,
  customer_id TEXT,
  branch_id   TEXT,
  status      TEXT NOT NULL DEFAULT 'pending',
  total       REAL NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_orders_status ON orders(status);
