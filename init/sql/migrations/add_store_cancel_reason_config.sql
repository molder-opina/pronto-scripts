-- Insertar parámetro para guardar el motivo de cancelación (MySQL)
INSERT INTO business_config (config_key, config_value, value_type, category, display_name, description, updated_at)
VALUES (
    'store_cancel_reason',
    'true',
    'bool',
    'orders',
    'Guardar motivo de cancelación',
    'Si está activo se guardan los motivos cuando cliente o mesero cancelan una orden.',
    NOW()
)
ON DUPLICATE KEY UPDATE
    config_value = VALUES(config_value),
    value_type = VALUES(value_type),
    category = VALUES(category),
    display_name = VALUES(display_name),
    description = VALUES(description),
    updated_at = NOW();
