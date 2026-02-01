-- Agregar parámetros de configuración para campanita y realtime (MySQL)

-- Cooldown de la campanita del mesero
INSERT INTO business_config (config_key, config_value, value_type, category, display_name, description, updated_at)
VALUES (
    'waiter_call_cooldown_seconds',
    '10',
    'integer',
    'general',
    'Cooldown de campanita (segundos)',
    'Tiempo en segundos que la campanita permanece roja después de confirmar. Durante este tiempo no se permiten nuevas notificaciones.',
    NOW()
)
ON DUPLICATE KEY UPDATE
    config_value = VALUES(config_value),
    description = VALUES(description),
    updated_at = NOW();

-- Intervalo de polling de eventos en tiempo real
INSERT INTO business_config (config_key, config_value, value_type, category, display_name, description, updated_at)
VALUES (
    'realtime_poll_interval_ms',
    '1000',
    'integer',
    'advanced',
    'Intervalo de polling realtime (ms)',
    'Intervalo en milisegundos para consultar eventos en tiempo real. Valores más bajos = notificaciones más rápidas pero más carga en el servidor.',
    NOW()
)
ON DUPLICATE KEY UPDATE
    config_value = VALUES(config_value),
    description = VALUES(description),
    updated_at = NOW();
