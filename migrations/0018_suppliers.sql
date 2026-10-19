CREATE TABLE suppliers (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  email       TEXT,
  phone       TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
