-- Migration: Add is_active column to pronto_tables
-- Required by ORM model

ALTER TABLE pronto_tables ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
UPDATE pronto_tables SET is_active = true WHERE is_active IS NULL;
ALTER TABLE pronto_tables ALTER COLUMN is_active SET NOT NULL;
