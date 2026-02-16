ALTER TABLE pronto_menu_categories
ADD COLUMN IF NOT EXISTS display_order INTEGER DEFAULT 0;

WITH ordered AS (
  SELECT id, (ROW_NUMBER() OVER (ORDER BY name) - 1) * 10 AS computed_order
  FROM pronto_menu_categories
)
UPDATE pronto_menu_categories c
SET display_order = o.computed_order
FROM ordered o
WHERE c.id = o.id
  AND COALESCE(c.display_order, 0) = 0;

CREATE INDEX IF NOT EXISTS idx_menu_category_display_order ON pronto_menu_categories(display_order);
