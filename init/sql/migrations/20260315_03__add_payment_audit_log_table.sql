-- Add payment audit log table for tracking payment operations
-- Date: 2026-03-15

CREATE TABLE IF NOT EXISTS pronto_payment_audit_logs (
    id SERIAL PRIMARY KEY,
    payment_id UUID NOT NULL REFERENCES pronto_payments(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES pronto_dining_sessions(id) ON DELETE CASCADE,
    employee_id UUID REFERENCES pronto_employees(id) ON DELETE SET NULL,
    employee_role VARCHAR(32) NOT NULL,
    action VARCHAR(50) NOT NULL,
    payment_method VARCHAR(32) NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS ix_payment_audit_logs_payment_id ON pronto_payment_audit_logs(payment_id);
CREATE INDEX IF NOT EXISTS ix_payment_audit_logs_session_id ON pronto_payment_audit_logs(session_id);
CREATE INDEX IF NOT EXISTS ix_payment_audit_logs_employee_id ON pronto_payment_audit_logs(employee_id);
CREATE INDEX IF NOT EXISTS ix_payment_audit_logs_created_at ON pronto_payment_audit_logs(created_at);