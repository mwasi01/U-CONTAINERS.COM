CREATE TABLE social_follows (
  follower_id  TEXT NOT NULL,
  followee_id  TEXT NOT NULL,
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (follower_id, followee_id)
);
