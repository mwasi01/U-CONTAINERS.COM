CREATE TABLE audit_log (
  id          TEXT PRIMARY KEY,
  user_id     TEXT,
  action      TEXT NOT NULL,
  entity      TEXT,
  entity_id   TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
