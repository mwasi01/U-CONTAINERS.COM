CREATE TABLE payments (
  id            TEXT PRIMARY KEY,
  order_id      TEXT,
  provider      TEXT NOT NULL,
  amount        REAL NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending',
  reference     TEXT,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);
