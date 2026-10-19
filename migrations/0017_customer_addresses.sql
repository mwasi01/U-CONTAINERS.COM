CREATE TABLE customer_addresses (
  id           TEXT PRIMARY KEY,
  customer_id  TEXT NOT NULL,
  label        TEXT,
  line1        TEXT NOT NULL,
  city         TEXT,
  country      TEXT DEFAULT 'KE',
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (customer_id) REFERENCES customers(id)
);
