CREATE TABLE social_comments (
  id          TEXT PRIMARY KEY,
  post_id     TEXT NOT NULL,
  author_id   TEXT NOT NULL,
  body        TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (post_id) REFERENCES social_posts(id)
);
