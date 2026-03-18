-- Add correlation_id to payment audit logs
-- Reference: PRONTO-PAY-075 Observability & Tracing
ALTER TABLE pronto_payment_audit_logs ADD COLUMN IF NOT EXISTS correlation_id VARCHAR(100);
CREATE INDEX IF NOT EXISTS ix_payment_audit_logs_correlation_id ON pronto_payment_audit_logs(correlation_id);
