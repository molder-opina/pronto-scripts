-- Migration: Add display_order column to pronto_menu_categories
-- Created: 2026-02-06
-- Purpose: Match ORM model expectations

-- Add display_order column if it doesn't exist
ALTER TABLE pronto_menu_categories ADD COLUMN IF NOT EXISTS display_order INTEGER NOT NULL DEFAULT 0;

-- Copy sort_order values to display_order if display_order is 0 and sort_order exists
UPDATE pronto_menu_categories
SET display_order = sort_order
WHERE display_order = 0 AND sort_order IS NOT NULL;

-- If display_order is still 0, populate with sequential values based on existing name order
WITH ordered AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY name) as new_order
    FROM pronto_menu_categories
    WHERE display_order = 0
)
UPDATE pronto_menu_categories c
SET display_order = ordered.new_order
FROM ordered
WHERE c.id = ordered.id;
