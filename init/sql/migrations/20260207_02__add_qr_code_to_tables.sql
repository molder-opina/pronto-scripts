-- Agregar columna qr_code a pronto_tables
-- Esta migración corrige el bug donde la columna existía en el modelo pero no en BD
-- Fecha: 2026-02-07

-- 1. Agregar columna nullable primero (sin restricción UNIQUE)
ALTER TABLE pronto_tables ADD COLUMN qr_code VARCHAR(100);

-- 2. Generar códigos QR temporales para mesas existentes
UPDATE pronto_tables
SET qr_code = 'QR-' || REPLACE(table_number, ' ', '-') || '-' || LEFT(id::text, 8)
WHERE qr_code IS NULL;

-- 3. Crear índice único para qr_code (puede fallar si hay duplicados)
-- Si hay duplicados, eliminar uno por uno manualmente o ejecutar seed.py
CREATE UNIQUE INDEX ix_table_qr_code ON pronto_tables(qr_code);

-- Comentario
COMMENT ON COLUMN pronto_tables.qr_code IS 'Código QR único para la mesa';
COMMENT ON TABLE pronto_tables IS 'Mesas del restaurante';
