CREATE TABLE product_variants (
  id          TEXT PRIMARY KEY,
  product_id  TEXT NOT NULL,
  name        TEXT NOT NULL,
  sku         TEXT UNIQUE,
  price       REAL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (product_id) REFERENCES products(id)
);
