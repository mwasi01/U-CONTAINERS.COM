CREATE TABLE users (
  id             TEXT PRIMARY KEY,
  email          TEXT UNIQUE NOT NULL,
  password_hash  TEXT NOT NULL,
  name           TEXT NOT NULL,
  role           TEXT NOT NULL DEFAULT 'customer',
  branch_id      TEXT,
  created_at     TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at     TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at     TEXT
);
CREATE INDEX idx_users_email ON users(email);
