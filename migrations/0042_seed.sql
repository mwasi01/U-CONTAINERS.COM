INSERT OR IGNORE INTO organizations (id, name, slug)
VALUES ('org_default', 'ngu-platform', 'ngu-platform');

INSERT OR IGNORE INTO branches (id, org_id, name, slug)
VALUES
  ('br_kikuyu', 'org_default', 'Kikuyu', 'kikuyu'),
  ('br_nakuru', 'org_default', 'Nakuru', 'nakuru');

INSERT OR IGNORE INTO categories (id, name, slug) VALUES
  ('cat_drums',      'Drums & Containers', 'drums-containers'),
  ('cat_jikos',      'Jikos',              'jikos'),
  ('cat_farming',    'Farming Tools',      'farming-tools'),
  ('cat_accessories','Accessories',        'accessories');

INSERT OR IGNORE INTO roles (id, name) VALUES
  ('role_owner',      'owner'),
  ('role_admin',      'admin'),
  ('role_manager',    'manager'),
  ('role_supervisor', 'supervisor'),
  ('role_staff',      'staff'),
  ('role_customer',   'customer');
