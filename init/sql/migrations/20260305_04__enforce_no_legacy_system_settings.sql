-- Migration: Enforce removal of legacy system setting keys
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
        'DELETE FROM pronto_system_settings WHERE %I IN (%L,%L,%L,%L)',
        key_col,
        'checkout_prompt_duration_seconds',
        'show_estimated_time',
        'estimated_time_min',
        'estimated_time_max'
    );

    -- Ensure canonical equivalents exist (idempotent)
    EXECUTE format(
        'INSERT INTO pronto_system_settings (%I, %I, category, description, is_public)
         SELECT %L, %L, %L, %L, true
         WHERE NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE %I = %L)',
        key_col,
        val_col,
        'client.checkout.redirect_seconds',
        '6',
        'system',
        'Seconds before checkout preference auto-redirect.',
        key_col,
        'client.checkout.redirect_seconds'
    );

    EXECUTE format(
        'INSERT INTO pronto_system_settings (%I, %I, category, description, is_public)
         SELECT %L, %L, %L, %L, true
         WHERE NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE %I = %L)',
        key_col,
        val_col,
        'orders.show_estimated_time',
        'true',
        'system',
        'Show estimated preparation time in UI.',
        key_col,
        'orders.show_estimated_time'
    );

    EXECUTE format(
        'INSERT INTO pronto_system_settings (%I, %I, category, description, is_public)
         SELECT %L, %L, %L, %L, true
         WHERE NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE %I = %L)',
        key_col,
        val_col,
        'orders.estimated_time_min',
        '15',
        'system',
        'Estimated prep minimum minutes.',
        key_col,
        'orders.estimated_time_min'
    );

    EXECUTE format(
        'INSERT INTO pronto_system_settings (%I, %I, category, description, is_public)
         SELECT %L, %L, %L, %L, true
         WHERE NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE %I = %L)',
        key_col,
        val_col,
        'orders.estimated_time_max',
        '30',
        'system',
        'Estimated prep maximum minutes.',
        key_col,
        'orders.estimated_time_max'
    );
END $$;

COMMIT;
