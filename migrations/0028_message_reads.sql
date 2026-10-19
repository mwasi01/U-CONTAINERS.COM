CREATE TABLE message_reads (
  message_id  TEXT NOT NULL,
  user_id     TEXT NOT NULL,
  read_at     TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (message_id, user_id)
);
