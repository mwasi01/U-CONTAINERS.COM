CREATE TABLE branches (
  id          TEXT PRIMARY KEY,
  org_id      TEXT NOT NULL,
  name        TEXT NOT NULL,
  slug        TEXT UNIQUE NOT NULL,
  address     TEXT,
  phone       TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
  deleted_at  TEXT,
  FOREIGN KEY (org_id) REFERENCES organizations(id)
);
