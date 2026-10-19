-- 0047_product_image.sql — add image URL column to products
ALTER TABLE products ADD COLUMN image TEXT DEFAULT NULL;
