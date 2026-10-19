CREATE TABLE social_reports (
  id          TEXT PRIMARY KEY,
  post_id     TEXT,
  reporter_id TEXT,
  reason      TEXT,
  status      TEXT NOT NULL DEFAULT 'open',
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
