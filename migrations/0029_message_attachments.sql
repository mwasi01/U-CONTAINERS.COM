CREATE TABLE message_attachments (
  id          TEXT PRIMARY KEY,
  message_id  TEXT NOT NULL,
  url         TEXT NOT NULL,
  mime        TEXT,
  FOREIGN KEY (message_id) REFERENCES messages(id)
);
