-- Migration: Remove legacy config keys and keep canonical names only
-- Date: 2026-03-05

BEGIN;

DO $$
BEGIN
    -- Keep canonical key if it does not exist yet.
    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'client_session_ttl_seconds')
       AND NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'system.session.client_ttl_seconds') THEN
        UPDATE pronto_system_settings
        SET key = 'system.session.client_ttl_seconds'
        WHERE key = 'client_session_ttl_seconds';
    END IF;

    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'employee_session_ttl_hours')
       AND NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'system.session.employee_ttl_hours') THEN
        UPDATE pronto_system_settings
        SET key = 'system.session.employee_ttl_hours'
        WHERE key = 'employee_session_ttl_hours';
    END IF;

    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'kiosk_session_non_expiring')
       AND NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'session.kiosk_non_expiring') THEN
        UPDATE pronto_system_settings
        SET key = 'session.kiosk_non_expiring'
        WHERE key = 'kiosk_session_non_expiring';
    END IF;

    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'checkout_prompt_duration_seconds')
       AND NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'client.checkout.redirect_seconds') THEN
        UPDATE pronto_system_settings
        SET key = 'client.checkout.redirect_seconds'
        WHERE key = 'checkout_prompt_duration_seconds';
    END IF;

    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'show_estimated_time')
       AND NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'orders.show_estimated_time') THEN
        UPDATE pronto_system_settings
        SET key = 'orders.show_estimated_time'
        WHERE key = 'show_estimated_time';
    END IF;

    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'estimated_time_min')
       AND NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'orders.estimated_time_min') THEN
        UPDATE pronto_system_settings
        SET key = 'orders.estimated_time_min'
        WHERE key = 'estimated_time_min';
    END IF;

    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'estimated_time_max')
       AND NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'orders.estimated_time_max') THEN
        UPDATE pronto_system_settings
        SET key = 'orders.estimated_time_max'
        WHERE key = 'estimated_time_max';
    END IF;

    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'paid_orders_window_minutes')
       AND NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'orders.paid_window_minutes') THEN
        UPDATE pronto_system_settings
        SET key = 'orders.paid_window_minutes'
        WHERE key = 'paid_orders_window_minutes';
    END IF;

    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'items_per_page')
       AND NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'system.api.items_per_page') THEN
        UPDATE pronto_system_settings
        SET key = 'system.api.items_per_page'
        WHERE key = 'items_per_page';
    END IF;
END $$;

DELETE FROM pronto_system_settings
WHERE key IN (
    'client_session_ttl_seconds',
    'employee_session_ttl_hours',
    'kiosk_session_non_expiring',
    'checkout_prompt_duration_seconds',
    'show_estimated_time',
    'estimated_time_min',
    'estimated_time_max',
    'paid_orders_window_minutes',
    'items_per_page',
    'RESTAURANT_NAME'
);

COMMIT;
