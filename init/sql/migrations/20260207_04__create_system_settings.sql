-- Crear tabla de configuración del sistema
-- Almacena settings globales como show_estimated_time, tiempos, etc.
-- Fecha: 2026-02-07

-- 1. Crear tabla pronto_system_settings
CREATE TABLE IF NOT EXISTS pronto_system_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(100) UNIQUE NOT NULL,
    value TEXT NOT NULL,
    value_type VARCHAR(20) NOT NULL DEFAULT 'string',
    description TEXT,
    category VARCHAR(50) NOT NULL DEFAULT 'general',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Índices para mejor rendimiento
CREATE INDEX IF NOT EXISTS idx_system_settings_key ON pronto_system_settings(key);
CREATE INDEX IF NOT EXISTS idx_system_settings_category ON pronto_system_settings(category);

-- 3. Insertar settings básicos requeridos por el frontend
INSERT INTO pronto_system_settings (key, value, value_type, description, category) VALUES
    ('show_estimated_time', 'true', 'boolean', 'Mostrar tiempo estimado de preparación', 'menu'),
    ('estimated_time_min', '15', 'integer', 'Tiempo mínimo de preparación (minutos)', 'menu'),
    ('estimated_time_max', '25', 'integer', 'Tiempo máximo de preparación (minutos)', 'menu'),
    ('checkout_prompt_duration_seconds', '6', 'integer', 'Duración del prompt de checkout en segundos', 'checkout'),
    ('currency_symbol', '$', 'string', 'Símbolo de moneda', 'general'),
    ('currency_code', 'MXN', 'string', 'Código de moneda ISO', 'general'),
    ('restaurant_name', 'Cafetería De Prueba', 'string', 'Nombre del restaurante', 'general')
ON CONFLICT (key) DO NOTHING;

-- Comentarios para documentación
COMMENT ON TABLE pronto_system_settings IS
    'Tabla de configuración de settings del sistema';
COMMENT ON COLUMN pronto_system_settings.key IS
    'Clave única del setting';
COMMENT ON COLUMN pronto_system_settings.value_type IS
    'Tipo de valor: string, integer, boolean, etc.';
COMMENT ON COLUMN pronto_system_settings.category IS
    'Categoría del setting (general, menu, checkout, etc.)';
