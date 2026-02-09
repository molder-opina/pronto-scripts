-- ============================================================================
-- PRONTO SEED: Areas
-- ============================================================================
-- Creates restaurant areas/zones with UPSERT logic
-- Run order: 0320 (after categories, before tables)
-- ============================================================================

-- Insert or update areas
INSERT INTO pronto_areas (name, description, prefix, color, is_active)
VALUES
    ('Terraza', 'Área exterior con vista', 'T', '#10b981', true),
    ('Salón Principal', 'Área interior principal', 'M', '#ff6b35', true),
    ('VIP', 'Área privada', 'V', '#8b5cf6', true),
    -- Additional areas for testing
    ('Bar', 'Área de bar y cocteles', 'B', '#f59e0b', true),
    ('Jardín', 'Área de jardín al aire libre', 'J', '#84cc16', true),
    ('Patio', 'Patio interior', 'P', '#06b6d4', true),
    ('Lounge', 'Área lounge', 'L', '#ec4899', true),
    ('Rooftop', 'Terraza en azotea', 'R', '#6366f1', true),
    ('Comedor Privado 1', 'Sala privada pequeña', 'C1', '#14b8a6', true),
    ('Comedor Privado 2', 'Sala privada mediana', 'C2', '#8b5cf6', true),
    ('Comedor Privado 3', 'Sala privada grande', 'C3', '#f43f5e', true),
    ('Terraza Cubierta', 'Terraza con techo', 'TC', '#10b981', true),
    ('Zona Familiar', 'Área para familias', 'ZF', '#fbbf24', true),
    ('Zona Ejecutiva', 'Área de negocios', 'ZE', '#3b82f6', true),
    ('Cafetería', 'Área de café', 'CF', '#a855f7', true),
    ('Sushi Bar', 'Barra de sushi', 'SB', '#ef4444', true),
    ('Parrilla', 'Área de parrilla', 'PR', '#f97316', true),
    ('Balcón', 'Balcón exterior', 'BL', '#22c55e', true),
    ('Sala de Eventos', 'Sala para eventos especiales', 'SE', '#6366f1', true),
    ('Área Infantil', 'Zona de juegos para niños', 'AI', '#ec4899', true)
ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    prefix = EXCLUDED.prefix,
    color = EXCLUDED.color,
    is_active = EXCLUDED.is_active;
