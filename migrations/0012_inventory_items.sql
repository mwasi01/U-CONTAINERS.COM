CREATE TABLE inventory_items (
  id             TEXT PRIMARY KEY,
  branch_id      TEXT NOT NULL,
  product_id     TEXT,
  sku            TEXT UNIQUE,
  serial         TEXT,
  quantity       INTEGER NOT NULL DEFAULT 0,
  reorder_level  INTEGER NOT NULL DEFAULT 0,
  created_at     TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at     TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_inventory_branch ON inventory_items(branch_id);
