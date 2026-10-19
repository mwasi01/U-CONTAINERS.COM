CREATE TABLE inventory_transfers (
  id            TEXT PRIMARY KEY,
  from_branch   TEXT NOT NULL,
  to_branch     TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending',
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  approved_at   TEXT,
  shipped_at    TEXT,
  received_at   TEXT
);
