-- Add waiter_can_collect system setting
-- Default to true to maintain existing behavior

INSERT INTO pronto_system_settings (key, value, value_type, category, description)
VALUES (
    'waiter_can_collect',
    'true',
    'bool',
    'payments',
    'Permite a los meseros procesar pagos y cerrar mesas. Si se desactiva, solo Cajeros y Administradores podrán hacerlo.'
) ON CONFLICT (key) DO NOTHING;
