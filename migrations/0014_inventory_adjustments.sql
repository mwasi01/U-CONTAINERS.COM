CREATE TABLE inventory_adjustments (
  id          TEXT PRIMARY KEY,
  item_id     TEXT NOT NULL,
  branch_id   TEXT NOT NULL,
  delta       INTEGER NOT NULL,
  reason      TEXT,
  user_id     TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
