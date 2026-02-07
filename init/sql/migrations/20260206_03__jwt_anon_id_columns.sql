-- Migration: Add anon_id columns for JWT dual mode authentication
-- Created: 2026-02-06
-- Branch: feat/fase2-jwt-dual-mode

-- Add anon_id column to pronto_customers table (nullable, unique)
-- This allows anonymous users to be linked before registration
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'pronto_customers' AND column_name = 'anon_id'
    ) THEN
        ALTER TABLE pronto_customers ADD COLUMN anon_id VARCHAR(36) UNIQUE;
    END IF;
END $$;

-- Add anon_id column to pronto_dining_sessions table (nullable, indexed)
-- This links dining sessions to anonymous users before registration
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'pronto_dining_sessions' AND column_name = 'anon_id'
    ) THEN
        ALTER TABLE pronto_dining_sessions ADD COLUMN anon_id VARCHAR(36);
    END IF;
END $$;

-- Create index on pronto_customers.anon_id for fast lookups
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'pronto_customers' AND indexname = 'ix_customer_anon_id'
    ) THEN
        CREATE INDEX ix_customer_anon_id ON pronto_customers(anon_id);
    END IF;
END $$;

-- Create index on pronto_dining_sessions.anon_id for fast lookups
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE tablename = 'pronto_dining_sessions' AND indexname = 'ix_dining_session_anon_id'
    ) THEN
        CREATE INDEX ix_dining_session_anon_id ON pronto_dining_sessions(anon_id);
    END IF;
END $$;

-- Verify columns were added
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name IN ('pronto_customers', 'pronto_dining_sessions')
-- ORDER BY table_name, column_name;
