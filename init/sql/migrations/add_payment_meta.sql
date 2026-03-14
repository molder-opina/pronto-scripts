
ALTER TABLE pronto_orders
ADD COLUMN IF NOT EXISTS payment_meta JSONB DEFAULT '{}';
