CREATE TABLE shifts (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL,
  branch_id   TEXT NOT NULL,
  clock_in    TEXT NOT NULL,
  clock_out   TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
