CREATE TABLE social_likes (
  post_id     TEXT NOT NULL,
  user_id     TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (post_id, user_id)
);
