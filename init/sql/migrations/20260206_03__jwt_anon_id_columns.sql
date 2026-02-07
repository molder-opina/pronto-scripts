-- Migration: 20260206_03__jwt_anon_id_columns.sql
-- Purpose: Add anonymous_id columns to support JWT authentication for guest users

ALTER TABLE pronto_orders
ADD COLUMN IF NOT EXISTS anonymous_client_id VARCHAR(36);

ALTER TABLE pronto_customers
ADD COLUMN IF NOT EXISTS anon_id VARCHAR(36) UNIQUE;

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_orders_anonymous_client_id ON pronto_orders(anonymous_client_id);
CREATE INDEX IF NOT EXISTS idx_customers_anon_id ON pronto_customers(anon_id);

-- Update existing orders with NULL anonymous_client_id to have valid UUIDs
DO $$
DECLARE
    o RECORD;
BEGIN
    FOR o IN SELECT id FROM pronto_orders WHERE anonymous_client_id IS NULL LOOP
        UPDATE pronto_orders
        SET anonymous_client_id = gen_random_uuid()
        WHERE id = o.id;
    END LOOP;
END $$;

COMMENT ON COLUMN pronto_orders.anonymous_client_id IS 'UUID identifier for anonymous/guest client orders';
COMMENT ON COLUMN pronto_customers.anon_id IS 'UUID identifier for customers who have not registered';
