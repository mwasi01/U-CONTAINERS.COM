CREATE TABLE customers (
  id          TEXT PRIMARY KEY,
  user_id     TEXT,
  email       TEXT NOT NULL,
  name        TEXT,
  phone       TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at  TEXT
);
