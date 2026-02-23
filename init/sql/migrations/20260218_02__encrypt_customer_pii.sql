-- Rename plaintext PII columns to deprecated
-- This completes the migration to encrypted columns for Customer PII

DO $$
BEGIN
    -- Rename email to email_deprecated if it exists
    IF EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'pronto_customers' AND column_name = 'email') THEN
        ALTER TABLE pronto_customers RENAME COLUMN email TO email_deprecated;
    END IF;

    -- Rename phone to phone_deprecated if it exists
    IF EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'pronto_customers' AND column_name = 'phone') THEN
        ALTER TABLE pronto_customers RENAME COLUMN phone TO phone_deprecated;
    END IF;

    -- Drop constraints on deprecated columns if necessary
    -- (e.g. unique constraint on email might need to be relaxed or moved to email_hash which implies uniqueness)
    -- idx_customer_email might exist.
    -- ix_customer_email_hash already exists and enforces uniqueness.
END $$;
