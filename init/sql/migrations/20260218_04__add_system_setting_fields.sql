-- Add missing fields to pronto_system_settings
ALTER TABLE pronto_system_settings
ADD COLUMN IF NOT EXISTS display_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS min_value DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS max_value DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS unit VARCHAR(32),
ADD COLUMN IF NOT EXISTS updated_by INTEGER;

-- Backfill display_name with key if null
UPDATE pronto_system_settings SET display_name = key WHERE display_name IS NULL;
