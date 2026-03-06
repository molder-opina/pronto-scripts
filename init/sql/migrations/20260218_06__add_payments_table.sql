-- Add payments table and tax info to customers

CREATE TABLE IF NOT EXISTS pronto_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES pronto_dining_sessions(id),
    amount NUMERIC(10, 2) NOT NULL,
    method VARCHAR(32) NOT NULL, -- cash, card, transfer
    reference VARCHAR(128),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES pronto_employees(id)
);

CREATE INDEX IF NOT EXISTS ix_pronto_payments_session_id ON pronto_payments(session_id);

-- Add tax info columns to customers
ALTER TABLE pronto_customers
ADD COLUMN IF NOT EXISTS tax_id VARCHAR(32), -- RFC
ADD COLUMN IF NOT EXISTS tax_name VARCHAR(255), -- Razon Social
ADD COLUMN IF NOT EXISTS tax_address TEXT,
ADD COLUMN IF NOT EXISTS tax_email VARCHAR(255);
