ALTER TABLE pronto_orders
ADD COLUMN IF NOT EXISTS anonymous_client_id VARCHAR(36);

ALTER TABLE pronto_customers
ADD COLUMN IF NOT EXISTS anon_id VARCHAR(36) UNIQUE;

CREATE INDEX IF NOT EXISTS idx_orders_anonymous_client_id ON pronto_orders(anonymous_client_id);
CREATE INDEX IF NOT EXISTS idx_customers_anon_id ON pronto_customers(anon_id);

UPDATE pronto_orders
SET anonymous_client_id = gen_random_uuid()::text
WHERE anonymous_client_id IS NULL;
