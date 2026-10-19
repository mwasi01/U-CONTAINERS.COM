CREATE TABLE roles (
  id    TEXT PRIMARY KEY,
  name  TEXT UNIQUE NOT NULL
);
CREATE TABLE permissions (
  id    TEXT PRIMARY KEY,
  name  TEXT UNIQUE NOT NULL
);
CREATE TABLE role_permissions (
  role_id        TEXT NOT NULL,
  permission_id  TEXT NOT NULL,
  PRIMARY KEY (role_id, permission_id)
);
