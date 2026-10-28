-- 0048_rename_nakuru_to_wangige.sql
-- The business owner renamed the second branch from "Nakuru" to "Wangige".
-- This updates the branch row, its slug, and any stock rows already tied to it.

-- Update the branch itself (safe even if already renamed)
UPDATE branches
SET
  id = CASE WHEN id = 'br_nakuru' THEN 'br_wangige' ELSE id END,
  name = 'Wangige',
  slug = 'wangige',
  updated_at = datetime('now')
WHERE id = 'br_nakuru' OR slug = 'nakuru';

-- Update any product_stock rows still pointing to br_nakuru
-- Note: product_stock uses (product_id, branch_id) primary key.
-- Renaming the branch id would orphan stock rows, so we recreate them
-- with the new branch id if needed. Since we changed branch.id above,
-- existing rows with branch_id='br_nakuru' would now point at a non-existent branch.
-- Handle by copying them to the new id first, then deleting old.

INSERT OR IGNORE INTO product_stock (product_id, branch_id, quantity, updated_at)
SELECT product_id, 'br_wangige', quantity, updated_at
FROM product_stock
WHERE branch_id = 'br_nakuru';

DELETE FROM product_stock WHERE branch_id = 'br_nakuru';

-- Update orders that were assigned to the old branch
UPDATE orders SET branch_id = 'br_wangige' WHERE branch_id = 'br_nakuru';
