DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_tables
        WHERE schemaname = 'public'
          AND tablename = 'pronto_business_config'
    ) AND NOT EXISTS (
        SELECT 1
        FROM pg_tables
        WHERE schemaname = 'public'
          AND tablename = 'pronto_system_settings'
    ) THEN
        ALTER TABLE pronto_business_config RENAME TO pronto_system_settings;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND indexname = 'ix_business_config_key'
    ) AND NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND indexname = 'ix_system_setting_key'
    ) THEN
        ALTER INDEX ix_business_config_key RENAME TO ix_system_setting_key;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND indexname = 'ix_business_config_category'
    ) AND NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND indexname = 'ix_system_setting_category'
    ) THEN
        ALTER INDEX ix_business_config_category RENAME TO ix_system_setting_category;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_class
        WHERE relname = 'pronto_business_config_id_seq'
    ) AND NOT EXISTS (
        SELECT 1
        FROM pg_class
        WHERE relname = 'pronto_system_settings_id_seq'
    ) THEN
        ALTER SEQUENCE pronto_business_config_id_seq RENAME TO pronto_system_settings_id_seq;
    END IF;
END $$;
