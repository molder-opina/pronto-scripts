-- Migration: 20260206_02__menu_category_display_order.sql
-- Purpose: Add display_order column to menu_categories for custom ordering

ALTER TABLE pronto_menu_categories
ADD COLUMN IF NOT EXISTS display_order INTEGER DEFAULT 0;

-- Update display_order for existing categories (alphabetical order as default)
DO $$
DECLARE
    cat RECORD;
    order_val INTEGER := 0;
BEGIN
    FOR cat IN SELECT id FROM pronto_menu_categories ORDER BY name LOOP
        UPDATE pronto_menu_categories
        SET display_order = order_val
        WHERE id = cat.id AND display_order = 0;
        order_val := order_val + 10;
    END LOOP;
END $$;

-- Create index for faster ordering queries
CREATE INDEX IF NOT EXISTS idx_menu_category_display_order ON pronto_menu_categories(display_order);

COMMENT ON COLUMN pronto_menu_categories.display_order IS 'Numeric value for custom category ordering (lower = appears first)';
