-- Migration: Ensure required system locale default setting exists
-- Date: 2026-03-05

BEGIN;

DO $$
DECLARE
    key_col text;
    val_col text;
BEGIN
    SELECT
        CASE
            WHEN EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_schema='public' AND table_name='pronto_system_settings' AND column_name='config_key'
            ) THEN 'config_key'
            ELSE 'key'
        END,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_schema='public' AND table_name='pronto_system_settings' AND column_name='config_value'
            ) THEN 'config_value'
            ELSE 'value'
        END
    INTO key_col, val_col;

    EXECUTE format(
        'INSERT INTO pronto_system_settings (%I, %I, value_type, category, display_name, description)
         SELECT %L, %L, %L, %L, %L, %L
         WHERE NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE %I = %L)',
        key_col,
        val_col,
        'system.locale.default',
        'es-MX',
        'string',
        'system',
        'Default Locale',
        'Default locale for user-facing messages and formatting.',
        key_col,
        'system.locale.default'
    );
END $$;

COMMIT;
