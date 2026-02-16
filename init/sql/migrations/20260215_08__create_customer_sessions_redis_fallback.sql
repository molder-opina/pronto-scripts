-- Migration: Create customer_sessions table for Redis fallback
-- Description: PostgreSQL fallback for customer sessions when Redis is unavailable
-- Author: Security remediation
-- Date: 2026-02-15

-- Customer sessions table for Redis fallback (availability)
CREATE TABLE IF NOT EXISTS customer_sessions (
    customer_ref UUID PRIMARY KEY,
    customer_id VARCHAR(255),
    email VARCHAR(255),
    name VARCHAR(255),
    phone VARCHAR(50),
    kind VARCHAR(50) DEFAULT 'customer',
    kiosk_location VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_seen_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for lookups
CREATE INDEX IF NOT EXISTS idx_customer_sessions_customer_id ON customer_sessions(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_sessions_last_seen_at ON customer_sessions(last_seen_at);

-- Add migration record
INSERT INTO schema_migrations (version, description, applied_at)
VALUES ('20260215_08', 'create_customer_sessions_redis_fallback', NOW())
ON CONFLICT (version) DO NOTHING;
