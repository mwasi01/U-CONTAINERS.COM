CREATE TABLE categories (
  id    TEXT PRIMARY KEY,
  name  TEXT NOT NULL,
  slug  TEXT UNIQUE NOT NULL
);
