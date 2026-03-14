-- Insertar parámetro para guardar el motivo de cancelación (PostgreSQL)
INSERT INTO pronto_system_settings (
    key,
    value,
    value_type,
    category,
    display_name,
    description,
    updated_at
)
VALUES (
    'store_cancel_reason',
    'true',
    'bool',
    'orders',
    'Guardar motivo de cancelación',
    'Si está activo se guardan los motivos cuando cliente o mesero cancelan una orden.',
    NOW()
)
ON CONFLICT (key) DO UPDATE
SET
    value = EXCLUDED.value,
    value_type = EXCLUDED.value_type,
    category = EXCLUDED.category,
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    updated_at = NOW();
