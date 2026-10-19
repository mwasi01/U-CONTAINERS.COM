CREATE TABLE purchase_orders (
  id          TEXT PRIMARY KEY,
  supplier_id TEXT NOT NULL,
  branch_id   TEXT,
  status      TEXT NOT NULL DEFAULT 'draft',
  total       REAL NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
);
