-- Deprecate order-level payment authority.
-- Canonical financial authority is pronto_payments + pronto_dining_sessions.

ALTER TABLE IF EXISTS pronto_orders
    ALTER COLUMN payment_status DROP NOT NULL;

ALTER TABLE IF EXISTS pronto_orders
    ALTER COLUMN payment_status DROP DEFAULT;

COMMENT ON COLUMN pronto_orders.payment_status IS
    'Legacy compatibility field. Financial authority is session/payment ledger.';
