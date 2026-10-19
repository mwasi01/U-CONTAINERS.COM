CREATE TABLE products (
  id             TEXT PRIMARY KEY,
  name           TEXT NOT NULL,
  slug           TEXT UNIQUE NOT NULL,
  description    TEXT,
  category_slug  TEXT,
  price          REAL NOT NULL DEFAULT 0,
  status         TEXT NOT NULL DEFAULT 'active',
  created_at     TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at     TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at     TEXT
);
CREATE INDEX idx_products_category ON products(category_slug);
