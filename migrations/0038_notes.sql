CREATE TABLE notes (
  id          TEXT PRIMARY KEY,
  author_id   TEXT,
  body        TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
