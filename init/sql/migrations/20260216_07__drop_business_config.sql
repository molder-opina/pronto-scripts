-- Migration: Drop pronto_business_config (replaced by pronto_system_settings)
-- Date: 2026-02-16
-- Description: Drop old business_config table since system_settings already exists with better schema

BEGIN;

-- Check if both tables exist and have data
DO $$
DECLARE
    bc_count INTEGER := 0;
    ss_count INTEGER := 0;
    bc_exists BOOLEAN;
BEGIN
    -- Check if business_config exists
    SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'pronto_business_config') INTO bc_exists;
    
    IF bc_exists THEN
        SELECT COUNT(*) INTO bc_count FROM pronto_business_config;
    END IF;
    
    SELECT COUNT(*) INTO ss_count FROM pronto_system_settings;
    
    RAISE NOTICE 'pronto_business_config rows: %', bc_count;
    RAISE NOTICE 'pronto_system_settings rows: %', ss_count;
    
    -- If business_config has data and system_settings is empty, warn
    IF bc_count > 0 AND ss_count = 0 THEN
        RAISE WARNING 'pronto_business_config has % rows but pronto_system_settings is empty. Manual data migration may be needed.', bc_count;
    END IF;
END $$;

-- Drop the old table (data should be in system_settings or will be seeded)
DROP TABLE IF EXISTS pronto_business_config CASCADE;

COMMIT;
