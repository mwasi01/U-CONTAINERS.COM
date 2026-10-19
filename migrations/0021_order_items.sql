CREATE TABLE order_items (
  id          TEXT PRIMARY KEY,
  order_id    TEXT NOT NULL,
  product_id  TEXT,
  name        TEXT NOT NULL,
  qty         INTEGER NOT NULL,
  price       REAL NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders(id)
);
