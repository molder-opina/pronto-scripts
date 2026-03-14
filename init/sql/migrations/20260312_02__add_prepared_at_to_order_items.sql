-- Add prepared_at field to order items table
-- This field tracks when an item is marked as ready by the kitchen

ALTER TABLE pronto_order_items 
ADD COLUMN IF NOT EXISTS prepared_at TIMESTAMP WITHOUT TIME ZONE;

-- Add index for efficient querying of prepared items
CREATE INDEX IF NOT EXISTS idx_order_items_prepared_at ON pronto_order_items(prepared_at) WHERE prepared_at IS NOT NULL;

-- Add comment for documentation
COMMENT ON COLUMN pronto_order_items.prepared_at IS 'Timestamp when the item was marked as ready by kitchen';