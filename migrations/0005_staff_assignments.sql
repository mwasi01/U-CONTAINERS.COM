CREATE TABLE staff_assignments (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL,
  branch_id    TEXT NOT NULL,
  department_id TEXT,
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (branch_id) REFERENCES branches(id)
);
