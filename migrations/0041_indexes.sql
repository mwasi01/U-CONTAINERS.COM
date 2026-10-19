CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_items_sku ON inventory_items(sku);
CREATE INDEX IF NOT EXISTS idx_posts_author ON social_posts(author_id);
