CREATE TABLE carts (
  id          TEXT PRIMARY KEY,
  customer_id TEXT,
  data        TEXT NOT NULL DEFAULT '{}',
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
