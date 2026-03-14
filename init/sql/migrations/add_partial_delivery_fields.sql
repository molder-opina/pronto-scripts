-- Migration: Add partial delivery fields to pronto_order_items table
-- This enables tracking individual item delivery for partial order fulfillment

-- Add delivery tracking fields to canonical table
ALTER TABLE pronto_order_items
ADD COLUMN IF NOT EXISTS delivered_quantity INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_fully_delivered BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP NULL,
ADD COLUMN IF NOT EXISTS delivered_by_employee_id INTEGER NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_order_items_delivered_by'
    ) THEN
        ALTER TABLE pronto_order_items
        ADD CONSTRAINT fk_order_items_delivered_by
        FOREIGN KEY (delivered_by_employee_id)
        REFERENCES pronto_employees(id) ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_delivered_quantity_valid'
    ) THEN
        ALTER TABLE pronto_order_items
        ADD CONSTRAINT chk_delivered_quantity_valid
        CHECK (delivered_quantity >= 0 AND delivered_quantity <= quantity);
    END IF;
END $$;

-- Add index for querying delivered items
CREATE INDEX IF NOT EXISTS ix_order_items_delivered
ON pronto_order_items(is_fully_delivered, delivered_at);

-- Add comment for documentation
COMMENT ON COLUMN pronto_order_items.delivered_quantity IS 'Number of units delivered to customer (supports partial delivery)';
COMMENT ON COLUMN pronto_order_items.is_fully_delivered IS 'True when delivered_quantity equals quantity';
COMMENT ON COLUMN pronto_order_items.delivered_at IS 'Timestamp when item was fully delivered';
COMMENT ON COLUMN pronto_order_items.delivered_by_employee_id IS 'Employee who delivered this item to the customer';
