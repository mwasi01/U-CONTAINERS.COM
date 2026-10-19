CREATE TABLE departments (
  id          TEXT PRIMARY KEY,
  branch_id   TEXT NOT NULL,
  name        TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at  TEXT,
  FOREIGN KEY (branch_id) REFERENCES branches(id)
);
