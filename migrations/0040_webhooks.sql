CREATE TABLE webhooks (
  id          TEXT PRIMARY KEY,
  provider    TEXT NOT NULL,
  payload     TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
