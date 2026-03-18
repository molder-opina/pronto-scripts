-- Create payment audit logs table
-- Reference: PRONTO-PAY-038 Financial Audit Incomplete
CREATE TABLE IF NOT EXISTS pronto_payment_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES pronto_dining_sessions(id),
    payment_id UUID REFERENCES pronto_payments(id),
    employee_id UUID REFERENCES pronto_employees(id),
    operation_type VARCHAR(50) NOT NULL, -- 'payment_created', 'payment_confirmed', 'session_closed', 'refund', etc.
    amount NUMERIC(12, 2),
    currency VARCHAR(10) DEFAULT 'MXN',
    payment_method VARCHAR(50),
    reference VARCHAR(255),
    metadata JSONB,
    client_ip VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_payment_audit_logs_session_id ON pronto_payment_audit_logs(session_id);
CREATE INDEX IF NOT EXISTS ix_payment_audit_logs_payment_id ON pronto_payment_audit_logs(payment_id);
CREATE INDEX IF NOT EXISTS ix_payment_audit_logs_employee_id ON pronto_payment_audit_logs(employee_id);
CREATE INDEX IF NOT EXISTS ix_payment_audit_logs_created_at ON pronto_payment_audit_logs(created_at);
