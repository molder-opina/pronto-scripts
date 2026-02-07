-- Migration: Add password_hash column for customer authentication
-- Created: 2026-02-07
-- Branch: feat/fase2-jwt-dual-mode

-- Add password_hash column to pronto_customers table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'pronto_customers' AND column_name = 'password_hash'
    ) THEN
        ALTER TABLE pronto_customers ADD COLUMN password_hash VARCHAR(255);
    END IF;
END $$;

-- Add email_hash column for fast lookups (derived from email)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'pronto_customers' AND column_name = 'email_hash'
    ) THEN
        ALTER TABLE pronto_customers ADD COLUMN email_hash VARCHAR(128);
    END IF;
END $$;

-- Create index on email_hash for fast lookups
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'pronto_customers' AND indexname = 'ix_customer_email_hash'
    ) THEN
        CREATE INDEX ix_customer_email_hash ON pronto_customers(email_hash);
    END IF;
END $$;

-- Verify columns were added
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_name = 'pronto_customers'
-- ORDER BY ordinal_position;
