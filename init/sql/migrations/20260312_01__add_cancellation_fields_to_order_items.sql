-- Add cancellation fields to order items table
-- This migration adds support for item-level cancellations

-- Add cancellation columns to pronto_order_items table
ALTER TABLE pronto_order_items 
ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP WITHOUT TIME ZONE,
ADD COLUMN IF NOT EXISTS cancelled_by VARCHAR(50),
ADD COLUMN IF NOT EXISTS cancellation_reason TEXT,
ADD COLUMN IF NOT EXISTS cancellation_type VARCHAR(50);

-- Add indexes for efficient querying of cancelled items
CREATE INDEX IF NOT EXISTS idx_order_items_cancelled_at ON pronto_order_items(cancelled_at) WHERE cancelled_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_order_items_cancelled_by ON pronto_order_items(cancelled_by) WHERE cancelled_by IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_order_items_cancellation_type ON pronto_order_items(cancellation_type) WHERE cancellation_type IS NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN pronto_order_items.cancelled_at IS 'Timestamp when the item was cancelled';
COMMENT ON COLUMN pronto_order_items.cancelled_by IS 'Role that cancelled the item (customer, waiter, admin, system)';
COMMENT ON COLUMN pronto_order_items.cancellation_reason IS 'Free text reason for cancellation';
COMMENT ON COLUMN pronto_order_items.cancellation_type IS 'Structured cancellation type (e.g., customer_changed_mind, kitchen_error, etc.)';