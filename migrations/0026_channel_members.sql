CREATE TABLE channel_members (
  channel_id  TEXT NOT NULL,
  user_id     TEXT NOT NULL,
  role        TEXT NOT NULL DEFAULT 'member',
  joined_at   TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (channel_id, user_id)
);
