CREATE TABLE transactions (
  id          TEXT PRIMARY KEY,
  kind        TEXT NOT NULL,
  amount      REAL NOT NULL,
  reference   TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
