-- 0045_product_management.sql — add cost, audit fields, and per-branch stock

-- cost: purchase cost per unit (used for profit calculation). NULL means unknown.
ALTER TABLE products ADD COLUMN cost REAL DEFAULT NULL;

-- updated_by: audit trail — who last edited the product
ALTER TABLE products ADD COLUMN updated_by TEXT DEFAULT NULL;

-- Per-branch stock levels (option 3: available at all branches, stock per branch)
CREATE TABLE IF NOT EXISTS product_stock (
  product_id  TEXT NOT NULL,
  branch_id   TEXT NOT NULL,
  quantity    INTEGER NOT NULL DEFAULT 0,
  updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (product_id, branch_id)
);

CREATE INDEX IF NOT EXISTS idx_product_stock_branch ON product_stock(branch_id);

-- Backfill: for each existing product, create stock rows for both branches with 0 qty
INSERT OR IGNORE INTO product_stock (product_id, branch_id, quantity)
SELECT p.id, b.id, 0
FROM products p
CROSS JOIN branches b;
