CREATE TABLE messages (
  id          TEXT PRIMARY KEY,
  channel_id  TEXT NOT NULL,
  author_id   TEXT NOT NULL,
  body        TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (channel_id) REFERENCES chat_channels(id)
);
CREATE INDEX idx_messages_channel ON messages(channel_id, created_at);
