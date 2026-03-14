-- Legacy MySQL aggregate migration kept for historical traceability.
-- All relevant schema/data changes are covered by canonical PostgreSQL migrations.
-- This script intentionally performs no mutations.
DO $$
BEGIN
    RAISE NOTICE 'apply_all_migrations.sql is deprecated/no-op on PostgreSQL';
END $$;
