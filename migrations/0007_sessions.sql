CREATE TABLE sessions_audit (
  id         TEXT PRIMARY KEY,
  user_id    TEXT,
  action     TEXT,
  ip         TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
