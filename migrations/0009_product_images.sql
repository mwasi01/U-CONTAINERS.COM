CREATE TABLE product_images (
  id          TEXT PRIMARY KEY,
  product_id  TEXT NOT NULL,
  url         TEXT NOT NULL,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (product_id) REFERENCES products(id)
);
