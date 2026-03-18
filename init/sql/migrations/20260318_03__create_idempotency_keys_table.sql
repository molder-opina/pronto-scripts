-- Create idempotency_keys table for payment operations
CREATE TABLE IF NOT EXISTS pronto_idempotency_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES pronto_dining_sessions(id) ON DELETE CASCADE,
    key VARCHAR(255) NOT NULL,
    payment_id UUID REFERENCES pronto_payments(id) ON DELETE SET NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS ix_idempotency_key_session ON pronto_idempotency_keys(session_id, key);
CREATE INDEX IF NOT EXISTS ix_idempotency_key_created ON pronto_idempotency_keys(created_at);

-- Add cleanup function for expired keys
CREATE OR REPLACE FUNCTION cleanup_expired_idempotency_keys()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM pronto_idempotency_keys 
    WHERE expires_at <= NOW();
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;