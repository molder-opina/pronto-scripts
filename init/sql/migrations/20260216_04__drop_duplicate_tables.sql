-- Migration: Drop duplicate tables
-- Date: 2026-02-16
-- Description: Remove branding_config and schema_migrations (superseded by pronto_* versions)

BEGIN;

-- Drop branding_config (empty, use pronto_business_config instead)
DROP TABLE IF EXISTS branding_config CASCADE;

-- Drop schema_migrations (1 row, use pronto_schema_migrations with 42 rows instead)
DROP TABLE IF EXISTS schema_migrations CASCADE;

COMMIT;
