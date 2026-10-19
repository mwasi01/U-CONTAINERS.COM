CREATE TABLE chat_channels (
  id          TEXT PRIMARY KEY,
  type        TEXT NOT NULL,
  reference   TEXT,
  title       TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
