-- Add slug and revision columns to pronto_menu_categories
-- Migration: 20260307_01__menu_category_slug_revision.sql

-- Add slug column (nullable first to populate existing rows)
ALTER TABLE pronto_menu_categories
ADD COLUMN IF NOT EXISTS slug VARCHAR(120);

-- Add revision column with default
ALTER TABLE pronto_menu_categories
ADD COLUMN IF NOT EXISTS revision INTEGER NOT NULL DEFAULT 1;

-- Generate slugs from names for existing categories
UPDATE pronto_menu_categories
SET slug = LOWER(REGEXP_REPLACE(
    REGEXP_REPLACE(name, '[^a-zA-Z0-9\s]', '', 'g'),
    '\s+', '-', 'g'
))
WHERE slug IS NULL;

-- Handle special case for "Sin clasificar"
UPDATE pronto_menu_categories
SET slug = 'sin-clasificar'
WHERE name = 'Sin clasificar';

-- Now make slug NOT NULL and add unique constraint
ALTER TABLE pronto_menu_categories
ALTER COLUMN slug SET NOT NULL;

-- Add unique constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_menu_categories_slug'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_class WHERE relname = 'uq_menu_categories_slug'
    ) THEN
        ALTER TABLE pronto_menu_categories
        ADD CONSTRAINT uq_menu_categories_slug UNIQUE (slug);
    END IF;
END $$;
