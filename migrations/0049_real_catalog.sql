-- 0049_real_catalog.sql
-- Wipe all transactional data (fresh start) and replace the demo product
-- catalog with the real NEVER GIVE UP ENTERPRISE inventory.

-- =============================================================================
-- 1. Clean all sales / transaction data
-- =============================================================================
DELETE FROM order_items;
DELETE FROM orders;
DELETE FROM payments;
DELETE FROM transactions;
DELETE FROM contact_messages;
DELETE FROM customers;

-- =============================================================================
-- 2. Remove the demo products (soft-delete so order history never orphaned)
-- =============================================================================
UPDATE products SET deleted_at = datetime('now')
WHERE id IN (
  'p_250l_open','p_250l_closed','p_170l_funiko','p_120l',
  'p_small_jiko','p_std_jiko','p_med_jiko','p_size13_jiko',
  'p_spade','p_rake_sm','p_rake_big','p_fork_jembe',
  'p_vifuniko','p_metal_drum'
);

-- =============================================================================
-- 3. Insert the 29 real products with cost, price, and status
-- =============================================================================
INSERT OR IGNORE INTO products
  (id, name, slug, description, category_slug, price, cost, status, created_at, updated_at)
VALUES
  -- Drums
  ('p_250l_drum',      '250L Drum',                '250l-drum',             'Heavy-duty 250 litre plastic drum.',              'drums-containers', 1500, 1250, 'active', datetime('now'), datetime('now')),
  ('p_170l_drum',      '170L Drum',                '170l-drum',             '170 litre plastic drum.',                          'drums-containers', 3000, 1500, 'active', datetime('now'), datetime('now')),
  ('p_120l_drum',      '120L Drum',                '120l-drum',             '120 litre plastic drum.',                          'drums-containers', 1500, 1100, 'active', datetime('now'), datetime('now')),
  ('p_80l_drum',       '80L Plastic Drum',         '80l-plastic-drum',      '80 litre plastic drum.',                           'drums-containers',  950,  550, 'active', datetime('now'), datetime('now')),
  ('p_50l_drum',       '50L Drum',                 '50l-drum',              '50 litre plastic drum.',                           'drums-containers',  750,  350, 'active', datetime('now'), datetime('now')),
  ('p_metal_drum',     'Metal Drum',               'metal-drum',            'Heavy-duty metal drum.',                            'drums-containers', 2200, 1500, 'active', datetime('now'), datetime('now')),
  ('p_1000l_tank',     'IBC Water Tank 1000L',     'ibc-water-tank-1000l',  'IBC square water tank 1000L with galvanized frame.', 'drums-containers',15000, 12000,'active', datetime('now'), datetime('now')),

  -- Buckets & small containers
  ('p_bucket_short',   'Big White Bucket (Short)', 'big-white-bucket-short','Large white plastic bucket — short.',              'drums-containers',  850,  550, 'active', datetime('now'), datetime('now')),
  ('p_bucket_long',    'Big White Bucket (Long)',  'big-white-bucket-long', 'Large white plastic bucket — long.',               'drums-containers',  750,  550, 'active', datetime('now'), datetime('now')),
  ('p_bucket_10l',     '10L Bucket',               '10l-bucket',            '10 litre plastic bucket.',                          'accessories',       230,  170, 'active', datetime('now'), datetime('now')),
  ('p_bucket_20l',     '20L Clean Bucket',         '20l-clean-bucket',      '20 litre clean plastic bucket.',                    'accessories',       250,  220, 'active', datetime('now'), datetime('now')),
  ('p_dirty_bucket',   'Dirty Bucket',             'dirty-bucket',          'Dirty bucket — mixed use.',                          'accessories',       230,  170, 'active', datetime('now'), datetime('now')),

  -- Small mtungi / vibuyu
  ('p_mtungi_20l',     '20L Mtungi',               '20l-mtungi',            '20 litre mtungi (clay pot).',                        'accessories',       100,   50, 'active', datetime('now'), datetime('now')),
  ('p_mtungi_10l',     '10L Mtungi',               '10l-mtungi',            '10 litre mtungi.',                                   'accessories',        70,   30, 'active', datetime('now'), datetime('now')),
  ('p_mtungi_40l',     '40L Mtungi',               '40l-mtungi',            '40 litre mtungi.',                                   'accessories',       500,  250, 'active', datetime('now'), datetime('now')),
  ('p_vibuyu_5l',      '5L Vibuyu',                '5l-vibuyu',             '5 litre vibuyu (small pot).',                        'accessories',        50,   25, 'active', datetime('now'), datetime('now')),
  ('p_kasuku_4l',      '4L Kasuku',                '4l-kasuku',             '4 litre kasuku (small container).',                  'accessories',       100,   60, 'active', datetime('now'), datetime('now')),

  -- Jikos
  ('p_jiko_small',     'Small Jiko',               'small-jiko',            'Compact charcoal jiko — single person.',             'jikos',             280,  190, 'active', datetime('now'), datetime('now')),
  ('p_jiko_standard',  'Standard Jiko',            'standard-jiko',         'Standard family-size charcoal jiko.',                'jikos',             350,  230, 'active', datetime('now'), datetime('now')),
  ('p_jiko_medium',    'Medium Jiko',              'medium-jiko',           'Medium size jiko with extra capacity.',              'jikos',             450,  250, 'active', datetime('now'), datetime('now')),
  ('p_jiko_size12',    'Size 12 Jiko',             'size-12-jiko',          'Size 12 commercial jiko.',                           'jikos',             550,  350, 'active', datetime('now'), datetime('now')),
  ('p_jiko_size13',    'Size 13 Jiko',             'size-13-jiko',          'Size 13 commercial jiko.',                           'jikos',             750,  450, 'active', datetime('now'), datetime('now')),
  ('p_jiko_size15',    'Size 15 Jiko',             'size-15-jiko',          'Size 15 large commercial jiko.',                     'jikos',            1200,  650, 'active', datetime('now'), datetime('now')),

  -- Farming tools
  ('p_spade',          'Spade',                    'spade',                 'Steel-headed spade with reinforced handle.',         'farming-tools',     450,  300, 'active', datetime('now'), datetime('now')),
  ('p_rake_big',       'Big Rake',                 'big-rake',              'Heavy-duty rake for field work.',                    'farming-tools',     450,  250, 'active', datetime('now'), datetime('now')),
  ('p_rake_small',     'Small Rake',               'small-rake',            'Compact rake for garden cleanup.',                   'farming-tools',     350,  200, 'active', datetime('now'), datetime('now')),
  ('p_fork_jembe',     'Fork Jembe',               'fork-jembe',            'Traditional four-tine fork jembe.',                  'farming-tools',     450,  250, 'active', datetime('now'), datetime('now')),
  ('p_slasher',        'Slasher',                  'slasher',               'Steel slasher for clearing brush and grass.',        'farming-tools',     350,  220, 'active', datetime('now'), datetime('now')),

  -- Misc
  ('p_vifuniko_metal', 'Vifuniko Metal',           'vifuniko-metal',        'Metal drum cover / vifuniko.',                       'accessories',       300,  200, 'active', datetime('now'), datetime('now')),
  ('p_mabati',         'Mabati Sheet',             'mabati-sheet',          'Corrugated iron sheet (mabati).',                    'accessories',      1500, 1000, 'active', datetime('now'), datetime('now'));

-- =============================================================================
-- 4. Set stock levels per branch
--    Wangige is the new branch, Kikuyu is the original.
--    Split real stock: Wangige = 60% of stock, Kikuyu = 40%
--    (Adjust these numbers if you want specific per-branch quantities)
-- =============================================================================
-- Clear old stock rows for these new products, then insert fresh
DELETE FROM product_stock WHERE product_id LIKE 'p_%';

INSERT OR REPLACE INTO product_stock (product_id, branch_id, quantity, updated_at)
SELECT
  p.id,
  'br_wangige',
  CAST(ROUND((CASE p.id
    WHEN 'p_250l_drum'      THEN 12
    WHEN 'p_170l_drum'      THEN 2
    WHEN 'p_120l_drum'      THEN 31
    WHEN 'p_80l_drum'       THEN 23
    WHEN 'p_50l_drum'       THEN 6
    WHEN 'p_metal_drum'     THEN 3
    WHEN 'p_1000l_tank'     THEN 1
    WHEN 'p_bucket_short'   THEN 6
    WHEN 'p_bucket_long'    THEN 11
    WHEN 'p_bucket_10l'     THEN 23
    WHEN 'p_bucket_20l'     THEN 33
    WHEN 'p_dirty_bucket'   THEN 19
    WHEN 'p_mtungi_20l'     THEN 8
    WHEN 'p_mtungi_10l'     THEN 28
    WHEN 'p_mtungi_40l'     THEN 1
    WHEN 'p_vibuyu_5l'      THEN 19
    WHEN 'p_kasuku_4l'      THEN 11
    WHEN 'p_jiko_small'     THEN 11
    WHEN 'p_jiko_standard'  THEN 19
    WHEN 'p_jiko_medium'    THEN 18
    WHEN 'p_jiko_size12'    THEN 15
    WHEN 'p_jiko_size13'    THEN 9
    WHEN 'p_jiko_size15'    THEN 8
    WHEN 'p_spade'          THEN 1
    WHEN 'p_rake_big'       THEN 3
    WHEN 'p_rake_small'     THEN 5
    WHEN 'p_fork_jembe'     THEN 1
    WHEN 'p_slasher'        THEN 8
    WHEN 'p_vifuniko_metal' THEN 10
    WHEN 'p_mabati'         THEN 8
    ELSE 0
  END) * 0.6) AS INTEGER),
  datetime('now')
FROM products p
WHERE p.deleted_at IS NULL;

INSERT OR REPLACE INTO product_stock (product_id, branch_id, quantity, updated_at)
SELECT
  p.id,
  'br_kikuyu',
  CAST((CASE p.id
    WHEN 'p_250l_drum'      THEN 12
    WHEN 'p_170l_drum'      THEN 2
    WHEN 'p_120l_drum'      THEN 31
    WHEN 'p_80l_drum'       THEN 23
    WHEN 'p_50l_drum'       THEN 6
    WHEN 'p_metal_drum'     THEN 3
    WHEN 'p_1000l_tank'     THEN 1
    WHEN 'p_bucket_short'   THEN 6
    WHEN 'p_bucket_long'    THEN 11
    WHEN 'p_bucket_10l'     THEN 23
    WHEN 'p_bucket_20l'     THEN 33
    WHEN 'p_dirty_bucket'   THEN 19
    WHEN 'p_mtungi_20l'     THEN 8
    WHEN 'p_mtungi_10l'     THEN 28
    WHEN 'p_mtungi_40l'     THEN 1
    WHEN 'p_vibuyu_5l'      THEN 19
    WHEN 'p_kasuku_4l'      THEN 11
    WHEN 'p_jiko_small'     THEN 11
    WHEN 'p_jiko_standard'  THEN 19
    WHEN 'p_jiko_medium'    THEN 18
    WHEN 'p_jiko_size12'    THEN 15
    WHEN 'p_jiko_size13'    THEN 9
    WHEN 'p_jiko_size15'    THEN 8
    WHEN 'p_spade'          THEN 1
    WHEN 'p_rake_big'       THEN 3
    WHEN 'p_rake_small'     THEN 5
    WHEN 'p_fork_jembe'     THEN 1
    WHEN 'p_slasher'        THEN 8
    WHEN 'p_vifuniko_metal' THEN 10
    WHEN 'p_mabati'         THEN 8
    ELSE 0
  END) - CAST(ROUND((CASE p.id
    WHEN 'p_250l_drum'      THEN 12
    WHEN 'p_170l_drum'      THEN 2
    WHEN 'p_120l_drum'      THEN 31
    WHEN 'p_80l_drum'       THEN 23
    WHEN 'p_50l_drum'       THEN 6
    WHEN 'p_metal_drum'     THEN 3
    WHEN 'p_1000l_tank'     THEN 1
    WHEN 'p_bucket_short'   THEN 6
    WHEN 'p_bucket_long'    THEN 11
    WHEN 'p_bucket_10l'     THEN 23
    WHEN 'p_bucket_20l'     THEN 33
    WHEN 'p_dirty_bucket'   THEN 19
    WHEN 'p_mtungi_20l'     THEN 8
    WHEN 'p_mtungi_10l'     THEN 28
    WHEN 'p_mtungi_40l'     THEN 1
    WHEN 'p_vibuyu_5l'      THEN 19
    WHEN 'p_kasuku_4l'      THEN 11
    WHEN 'p_jiko_small'     THEN 11
    WHEN 'p_jiko_standard'  THEN 19
    WHEN 'p_jiko_medium'    THEN 18
    WHEN 'p_jiko_size12'    THEN 15
    WHEN 'p_jiko_size13'    THEN 9
    WHEN 'p_jiko_size15'    THEN 8
    WHEN 'p_spade'          THEN 1
    WHEN 'p_rake_big'       THEN 3
    WHEN 'p_rake_small'     THEN 5
    WHEN 'p_fork_jembe'     THEN 1
    WHEN 'p_slasher'        THEN 8
    WHEN 'p_vifuniko_metal' THEN 10
    WHEN 'p_mabati'         THEN 8
    ELSE 0
  END) * 0.6) AS INTEGER)) AS INTEGER,
  datetime('now')
FROM products p
WHERE p.deleted_at IS NULL;
