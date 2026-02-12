-- Add workflow_status column to pronto_orders table
ALTER TABLE pronto_orders ADD COLUMN IF NOT EXISTS workflow_status VARCHAR(20) DEFAULT 'queued' NOT NULL;
