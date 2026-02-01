-- Migration: Add partial delivery fields to order_items table
-- This enables tracking individual item delivery for partial order fulfillment

-- Add delivery tracking fields to order_items
ALTER TABLE order_items
ADD COLUMN delivered_quantity INTEGER NOT NULL DEFAULT 0,
ADD COLUMN is_fully_delivered BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN delivered_at TIMESTAMP NULL,
ADD COLUMN delivered_by_employee_id INTEGER NULL,
ADD CONSTRAINT fk_order_items_delivered_by
    FOREIGN KEY (delivered_by_employee_id)
    REFERENCES employees(id) ON DELETE SET NULL,
ADD CONSTRAINT chk_delivered_quantity_valid
    CHECK (delivered_quantity >= 0 AND delivered_quantity <= quantity);

-- Add index for querying delivered items
CREATE INDEX ix_order_items_delivered ON order_items(is_fully_delivered, delivered_at);

-- Add comment for documentation
COMMENT ON COLUMN order_items.delivered_quantity IS 'Number of units delivered to customer (supports partial delivery)';
COMMENT ON COLUMN order_items.is_fully_delivered IS 'True when delivered_quantity equals quantity';
COMMENT ON COLUMN order_items.delivered_at IS 'Timestamp when item was fully delivered';
COMMENT ON COLUMN order_items.delivered_by_employee_id IS 'Employee who delivered this item to the customer';
