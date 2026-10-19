CREATE TABLE stock_counts (
  id          TEXT PRIMARY KEY,
  branch_id   TEXT NOT NULL,
  item_id     TEXT NOT NULL,
  counted     INTEGER NOT NULL,
  expected    INTEGER NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
