CREATE TABLE social_posts (
  id          TEXT PRIMARY KEY,
  author_id   TEXT NOT NULL,
  body        TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at  TEXT
);
