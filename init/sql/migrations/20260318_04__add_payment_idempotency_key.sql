-- Add idempotency_key column to pronto_payments for duplicate payment prevention
ALTER TABLE pronto_payments
ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(128);

-- Ensure idempotency keys are unique when present while allowing multiple NULL values
CREATE UNIQUE INDEX IF NOT EXISTS ix_payment_idempotency_key
ON pronto_payments (idempotency_key)
WHERE idempotency_key IS NOT NULL;

COMMENT ON COLUMN pronto_payments.idempotency_key IS
'Idempotency key for duplicate payment prevention. Unique per payment attempt when provided.';
