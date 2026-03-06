-- Create pronto_order_status_history table
CREATE TABLE IF NOT EXISTS pronto_order_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES pronto_orders(id),
    status VARCHAR(20) NOT NULL,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    changed_by UUID REFERENCES pronto_employees(id),
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_order_status_history_order_id ON pronto_order_status_history(order_id);
