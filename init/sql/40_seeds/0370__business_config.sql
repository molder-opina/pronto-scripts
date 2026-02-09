-- ============================================================================
-- PRONTO SEED: Business Configuration
-- ============================================================================
-- Creates initial business configuration
-- Run order: 0370 (after basic data)
-- ============================================================================

-- Insert or update business config
INSERT INTO pronto_business_config (
    id, restaurant_name, tax_rate, currency, timezone,
    enable_tips, default_tip_percentage, enable_reservations,
    enable_takeout, enable_delivery, created_at, updated_at
)
VALUES (
    1,
    COALESCE(current_setting('app.restaurant_name', true), 'Cafetería de Prueba'),
    0.16,  -- 16% IVA México
    'MXN',
    'America/Mexico_City',
    true,
    15.0,
    true,
    true,
    false,
    NOW(),
    NOW()
)
ON CONFLICT (id) DO UPDATE SET
    restaurant_name = EXCLUDED.restaurant_name,
    tax_rate = EXCLUDED.tax_rate,
    currency = EXCLUDED.currency,
    timezone = EXCLUDED.timezone,
    enable_tips = EXCLUDED.enable_tips,
    default_tip_percentage = EXCLUDED.default_tip_percentage,
    enable_reservations = EXCLUDED.enable_reservations,
    enable_takeout = EXCLUDED.enable_takeout,
    enable_delivery = EXCLUDED.enable_delivery,
    updated_at = NOW();

-- Insert or update business schedule (open 24/7 by default)
INSERT INTO pronto_business_schedule (day_of_week, is_open, open_time, close_time, notes)
VALUES
    (0, true, '00:00', '23:59', 'Lunes - Abierto todo el día'),
    (1, true, '00:00', '23:59', 'Martes - Abierto todo el día'),
    (2, true, '00:00', '23:59', 'Miércoles - Abierto todo el día'),
    (3, true, '00:00', '23:59', 'Jueves - Abierto todo el día'),
    (4, true, '00:00', '23:59', 'Viernes - Abierto todo el día'),
    (5, true, '00:00', '23:59', 'Sábado - Abierto todo el día'),
    (6, true, '00:00', '23:59', 'Domingo - Abierto todo el día')
ON CONFLICT (day_of_week) DO UPDATE SET
    is_open = EXCLUDED.is_open,
    open_time = EXCLUDED.open_time,
    close_time = EXCLUDED.close_time,
    notes = EXCLUDED.notes;
