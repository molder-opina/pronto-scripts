-- Migration: Normalize System Settings (V6 Strict Canon)
-- Date: 2026-02-26
-- Description: Normalize keys to lowercase, migrate RESTAURANT_NAME, and enforce category namespaces.

BEGIN;

-- Helper function to rename keys safely
DO $$
BEGIN
    -- restaurant_name
    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'RESTAURANT_NAME') AND 
       NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'restaurant_name') THEN
        UPDATE pronto_system_settings SET key = 'restaurant_name' WHERE key = 'RESTAURANT_NAME';
    END IF;

    -- orders.show_estimated_time
    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'show_estimated_time') AND 
       NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'orders.show_estimated_time') THEN
        UPDATE pronto_system_settings SET key = 'orders.show_estimated_time' WHERE key = 'show_estimated_time';
    END IF;

    -- orders.estimated_time_min
    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'estimated_time_min') AND 
       NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'orders.estimated_time_min') THEN
        UPDATE pronto_system_settings SET key = 'orders.estimated_time_min' WHERE key = 'estimated_time_min';
    END IF;

    -- orders.estimated_time_max
    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'estimated_time_max') AND 
       NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'orders.estimated_time_max') THEN
        UPDATE pronto_system_settings SET key = 'orders.estimated_time_max' WHERE key = 'estimated_time_max';
    END IF;

    -- orders.paid_window_minutes
    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'paid_orders_window_minutes') AND 
       NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'orders.paid_window_minutes') THEN
        UPDATE pronto_system_settings SET key = 'orders.paid_window_minutes' WHERE key = 'paid_orders_window_minutes';
    END IF;

    -- system.session.client_ttl_seconds
    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'client_session_ttl_seconds') AND 
       NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'system.session.client_ttl_seconds') THEN
        UPDATE pronto_system_settings SET key = 'system.session.client_ttl_seconds' WHERE key = 'client_session_ttl_seconds';
    END IF;

    -- system.session.employee_ttl_hours
    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'employee_session_ttl_hours') AND 
       NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'system.session.employee_ttl_hours') THEN
        UPDATE pronto_system_settings SET key = 'system.session.employee_ttl_hours' WHERE key = 'employee_session_ttl_hours';
    END IF;

    -- session.kiosk_non_expiring
    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'kiosk_session_non_expiring') AND 
       NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'session.kiosk_non_expiring') THEN
        UPDATE pronto_system_settings SET key = 'session.kiosk_non_expiring' WHERE key = 'kiosk_session_non_expiring';
    END IF;

    -- client.checkout.redirect_seconds
    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'checkout_prompt_duration_seconds') AND 
       NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'client.checkout.redirect_seconds') THEN
        UPDATE pronto_system_settings SET key = 'client.checkout.redirect_seconds' WHERE key = 'checkout_prompt_duration_seconds';
    END IF;

    -- system.api.items_per_page
    IF EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'items_per_page') AND 
       NOT EXISTS (SELECT 1 FROM pronto_system_settings WHERE key = 'system.api.items_per_page') THEN
        UPDATE pronto_system_settings SET key = 'system.api.items_per_page' WHERE key = 'items_per_page';
    END IF;

END $$;

-- 2. Delete ALL legacy keys with UPPERCASE characters (that were not renamed)
DELETE FROM pronto_system_settings WHERE key ~ '[A-Z]';

-- 3. Enforce category namespaces
-- System namespace
UPDATE pronto_system_settings 
SET category = 'system' 
WHERE key LIKE 'system.%';

-- Business namespace (everything else that is recognized by contract)
UPDATE pronto_system_settings 
SET category = 'business' 
WHERE key NOT LIKE 'system.%';

COMMIT;
