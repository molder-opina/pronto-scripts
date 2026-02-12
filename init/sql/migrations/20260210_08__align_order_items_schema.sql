-- Align pronto_order_items schema with OrderItem model

-- Rename columns
ALTER TABLE pronto_order_items RENAME COLUMN served_at TO delivered_at;

-- Add missing columns
ALTER TABLE pronto_order_items ADD COLUMN IF NOT EXISTS delivered_quantity INTEGER DEFAULT 0 NOT NULL;
ALTER TABLE pronto_order_items ADD COLUMN IF NOT EXISTS is_fully_delivered BOOLEAN DEFAULT FALSE NOT NULL;
ALTER TABLE pronto_order_items ADD COLUMN IF NOT EXISTS delivered_by_employee_id UUID;

-- Add foreign key for delivered_by_employee_id
ALTER TABLE pronto_order_items ADD CONSTRAINT fk_order_items_delivered_by 
    FOREIGN KEY (delivered_by_employee_id) REFERENCES pronto_employees(id);

-- Add indexes
CREATE INDEX IF NOT EXISTS ix_order_item_delivery_status ON pronto_order_items(is_fully_delivered, delivered_at);
