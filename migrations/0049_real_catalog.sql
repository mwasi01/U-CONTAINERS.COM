-- 0049_real_catalog.sql
-- Wipe transactional data and replace the demo catalog with real products.

-- =============================================================================
-- 1. Clean all sales / transactional data
-- =============================================================================
DELETE FROM order_items;
DELETE FROM orders;
DELETE FROM payments;
DELETE FROM transactions;
DELETE FROM contact_messages;
DELETE FROM customers;

-- =============================================================================
-- 2. Remove demo products completely (frees up slugs for reuse)
--    Safe because order_items is now empty.
-- =============================================================================
DELETE FROM product_stock;
DELETE FROM product_images;
DELETE FROM product_variants;
DELETE FROM products;

-- =============================================================================
-- 3. Insert the 30 real products
-- =============================================================================
INSERT INTO products (id, name, slug, description, category_slug, price, cost, status, created_at, updated_at)
VALUES
  ('p_250l_drum',      '250L Drum',                '250l-drum',             'Heavy-duty 250 litre plastic drum.',              'drums-containers', 1500, 1250, 'active', datetime('now'), datetime('now')),
  ('p_170l_drum',      '170L Drum',                '170l-drum',             '170 litre plastic drum.',                          'drums-containers', 3000, 1500, 'active', datetime('now'), datetime('now')),
  ('p_120l_drum',      '120L Drum',                '120l-drum',             '120 litre plastic drum.',                          'drums-containers', 1500, 1100, 'active', datetime('now'), datetime('now')),
  ('p_80l_drum',       '80L Plastic Drum',         '80l-plastic-drum',      '80 litre plastic drum.',                           'drums-containers',  950,  550, 'active', datetime('now'), datetime('now')),
  ('p_50l_drum',       '50L Drum',                 '50l-drum',              '50 litre plastic drum.',                           'drums-containers',  750,  350, 'active', datetime('now'), datetime('now')),
  ('p_metal_drum',     'Metal Drum',               'metal-drum-new',        'Heavy-duty metal drum.',                            'drums-containers', 2200, 1500, 'active', datetime('now'), datetime('now')),
  ('p_bucket_short',   'Big White Bucket (Short)', 'big-white-bucket-short','Large white plastic bucket — short.',              'drums-containers',  850,  550, 'active', datetime('now'), datetime('now')),
  ('p_bucket_long',    'Big White Bucket (Long)',  'big-white-bucket-long', 'Large white plastic bucket — long.',               'drums-containers',  750,  550, 'active', datetime('now'), datetime('now')),
  ('p_bucket_10l',     '10L Bucket',               '10l-bucket-new',        '10 litre plastic bucket.',                          'accessories',       230,  170, 'active', datetime('now'), datetime('now')),
  ('p_bucket_20l',     '20L Clean Bucket',         '20l-clean-bucket',      '20 litre clean plastic bucket.',                    'accessories',       250,  220, 'active', datetime('now'), datetime('now')),
  ('p_dirty_bucket',   'Dirty Bucket',             'dirty-bucket',          'Dirty bucket — mixed use.',                          'accessories',       230,  170, 'active', datetime('now'), datetime('now')),
  ('p_mtungi_20l',     '20L Mtungi',               '20l-mtungi',            '20 litre mtungi (clay pot).',                        'accessories',       100,   50, 'active', datetime('now'), datetime('now')),
  ('p_mtungi_10l',     '10L Mtungi',               '10l-mtungi',            '10 litre mtungi.',                                   'accessories',        70,   30, 'active', datetime('now'), datetime('now')),
  ('p_mtungi_40l',     '40L Mtungi',               '40l-mtungi',            '40 litre mtungi.',                                   'accessories',       500,  250, 'active', datetime('now'), datetime('now')),
  ('p_vibuyu_5l',      '5L Vibuyu',                '5l-vibuyu',             '5 litre vibuyu (small pot).',                        'accessories',        50,   25, 'active', datetime('now'), datetime('now')),
  ('p_kasuku_4l',      '4L Kasuku',                '4l-kasuku',             '4 litre kasuku (small container).',                  'accessories',       100,   60, 'active', datetime('now'), datetime('now')),
  ('p_jiko_small',     'Small Jiko',               'small-jiko-new',        'Compact charcoal jiko — single person.',             'jikos',             280,  190, 'active', datetime('now'), datetime('now')),
  ('p_jiko_standard',  'Standard Jiko',            'standard-jiko-new',     'Standard family-size charcoal jiko.',                'jikos',             350,  230, 'active', datetime('now'), datetime('now')),
  ('p_jiko_medium',    'Medium Jiko',              'medium-jiko-new',       'Medium size jiko with extra capacity.',              'jikos',             450,  250, 'active', datetime('now'), datetime('now')),
  ('p_jiko_size12',    'Size 12 Jiko',             'size-12-jiko',          'Size 12 commercial jiko.',                           'jikos',             550,  350, 'active', datetime('now'), datetime('now')),
  ('p_jiko_size13',    'Size 13 Jiko',             'size-13-jiko-new',      'Size 13 commercial jiko.',                           'jikos',             750,  450, 'active', datetime('now'), datetime('now')),
  ('p_jiko_size15',    'Size 15 Jiko',             'size-15-jiko',          'Size 15 large commercial jiko.',                     'jikos',            1200,  650, 'active', datetime('now'), datetime('now')),
  ('p_spade',          'Spade',                    'spade-new',             'Steel-headed spade with reinforced handle.',         'farming-tools',     450,  300, 'active', datetime('now'), datetime('now')),
  ('p_rake_big',       'Big Rake',                 'big-rake-new',          'Heavy-duty rake for field work.',                    'farming-tools',     450,  250, 'active', datetime('now'), datetime('now')),
  ('p_rake_small',     'Small Rake',               'small-rake-new',        'Compact rake for garden cleanup.',                   'farming-tools',     350,  200, 'active', datetime('now'), datetime('now')),
  ('p_fork_jembe',     'Fork Jembe',               'fork-jembe-new',        'Traditional four-tine fork jembe.',                  'farming-tools',     450,  250, 'active', datetime('now'), datetime('now')),
  ('p_slasher',        'Slasher',                  'slasher',               'Steel slasher for clearing brush and grass.',        'farming-tools',     350,  220, 'active', datetime('now'), datetime('now')),
  ('p_vifuniko_metal', 'Vifuniko Metal',           'vifuniko-metal-new',    'Metal drum cover / vifuniko.',                       'accessories',       300,  200, 'active', datetime('now'), datetime('now')),
  ('p_mabati',         'Mabati Sheet',             'mabati-sheet',          'Corrugated iron sheet (mabati).',                    'accessories',      1500, 1000, 'active', datetime('now'), datetime('now')),
  ('p_1000l_tank',     'IBC Water Tank 1000L',     'ibc-water-tank-1000l',  'IBC square water tank 1000L with galvanized frame.', 'drums-containers',15000, 12000,'active', datetime('now'), datetime('now'));

-- =============================================================================
-- 4. Stock per branch — Wangige 60%, Kikuyu 40%
-- =============================================================================
INSERT INTO product_stock (product_id, branch_id, quantity, updated_at) VALUES
  ('p_250l_drum',      'br_wangige',  7, datetime('now')),
  ('p_170l_drum',      'br_wangige',  1, datetime('now')),
  ('p_120l_drum',      'br_wangige', 19, datetime('now')),
  ('p_80l_drum',       'br_wangige', 14, datetime('now')),
  ('p_50l_drum',       'br_wangige',  4, datetime('now')),
  ('p_metal_drum',     'br_wangige',  2, datetime('now')),
  ('p_bucket_short',   'br_wangige',  4, datetime('now')),
  ('p_bucket_long',    'br_wangige',  7, datetime('now')),
  ('p_bucket_10l',     'br_wangige', 14, datetime('now')),
  ('p_bucket_20l',     'br_wangige', 20, datetime('now')),
  ('p_dirty_bucket',   'br_wangige', 11, datetime('now')),
  ('p_mtungi_20l',     'br_wangige',  5, datetime('now')),
  ('p_mtungi_10l',     'br_wangige', 17, datetime('now')),
  ('p_mtungi_40l',     'br_wangige',  1, datetime('now')),
  ('p_vibuyu_5l',      'br_wangige', 11, datetime('now')),
  ('p_kasuku_4l',      'br_wangige',  7, datetime('now')),
  ('p_jiko_small',     'br_wangige',  7, datetime('now')),
  ('p_jiko_standard',  'br_wangige', 11, datetime('now')),
  ('p_jiko_medium',    'br_wangige', 11, datetime('now')),
  ('p_jiko_size12',    'br_wangige',  9, datetime('now')),
  ('p_jiko_size13',    'br_wangige',  5, datetime('now')),
  ('p_jiko_size15',    'br_wangige',  5, datetime('now')),
  ('p_spade',          'br_wangige',  1, datetime('now')),
  ('p_rake_big',       'br_wangige',  2, datetime('now')),
  ('p_rake_small',     'br_wangige',  3, datetime('now')),
  ('p_fork_jembe',     'br_wangige',  1, datetime('now')),
  ('p_slasher',        'br_wangige',  5, datetime('now')),
  ('p_vifuniko_metal', 'br_wangige',  6, datetime('now')),
  ('p_mabati',         'br_wangige',  5, datetime('now')),
  ('p_1000l_tank',     'br_wangige',  1, datetime('now')),
  ('p_250l_drum',      'br_kikuyu',   5, datetime('now')),
  ('p_170l_drum',      'br_kikuyu',   1, datetime('now')),
  ('p_120l_drum',      'br_kikuyu',  12, datetime('now')),
  ('p_80l_drum',       'br_kikuyu',   9, datetime('now')),
  ('p_50l_drum',       'br_kikuyu',   2, datetime('now')),
  ('p_metal_drum',     'br_kikuyu',   1, datetime('now')),
  ('p_bucket_short',   'br_kikuyu',   2, datetime('now')),
  ('p_bucket_long',    'br_kikuyu',   4, datetime('now')),
  ('p_bucket_10l',     'br_kikuyu',   9, datetime('now')),
  ('p_bucket_20l',     'br_kikuyu',  13, datetime('now')),
  ('p_dirty_bucket',   'br_kikuyu',   8, datetime('now')),
  ('p_mtungi_20l',     'br_kikuyu',   3, datetime('now')),
  ('p_mtungi_10l',     'br_kikuyu',  11, datetime('now')),
  ('p_mtungi_40l',     'br_kikuyu',   0, datetime('now')),
  ('p_vibuyu_5l',      'br_kikuyu',   8, datetime('now')),
  ('p_kasuku_4l',      'br_kikuyu',   4, datetime('now')),
  ('p_jiko_small',     'br_kikuyu',   4, datetime('now')),
  ('p_jiko_standard',  'br_kikuyu',   8, datetime('now')),
  ('p_jiko_medium',    'br_kikuyu',   7, datetime('now')),
  ('p_jiko_size12',    'br_kikuyu',   6, datetime('now')),
  ('p_jiko_size13',    'br_kikuyu',   4, datetime('now')),
  ('p_jiko_size15',    'br_kikuyu',   3, datetime('now')),
  ('p_spade',          'br_kikuyu',   0, datetime('now')),
  ('p_rake_big',       'br_kikuyu',   1, datetime('now')),
  ('p_rake_small',     'br_kikuyu',   2, datetime('now')),
  ('p_fork_jembe',     'br_kikuyu',   0, datetime('now')),
  ('p_slasher',        'br_kikuyu',   3, datetime('now')),
  ('p_vifuniko_metal', 'br_kikuyu',   4, datetime('now')),
  ('p_mabati',         'br_kikuyu',   3, datetime('now')),
  ('p_1000l_tank',     'br_kikuyu',   0, datetime('now'));