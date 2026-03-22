-- Add unique constraint on (session_id, key) to prevent race condition duplicates
-- The idempotency store uses ON CONFLICT DO NOTHING, so this constraint
-- ensures exactly one idempotency key entry per session+key combination.
ALTER TABLE pronto_idempotency_keys
ADD CONSTRAINT uq_idempotency_keys_session_key
UNIQUE (session_id, key);

-- Drop the redundant non-unique index (unique constraint creates its own index)
DROP INDEX IF EXISTS ix_idempotency_key_session;

-- Create new unique index for the constraint
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS
    ix_idempotency_keys_session_key
    ON pronto_idempotency_keys(session_id, key);
