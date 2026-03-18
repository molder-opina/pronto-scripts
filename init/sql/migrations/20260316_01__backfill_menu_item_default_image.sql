-- Persist canonical default image for menu items that still have null/blank image_path.
-- This is a data normalization migration (no runtime fallback semantics).

WITH inferred_assets_root AS (
    SELECT COALESCE(
        (
            SELECT regexp_replace(image_path, '^(/assets/[^/]+)/.*$', '\1')
            FROM pronto_menu_items
            WHERE image_path IS NOT NULL
              AND btrim(image_path) <> ''
              AND image_path LIKE '/assets/%/%'
            LIMIT 1
        ),
        '/assets/pronto'
    ) AS assets_root
)
UPDATE pronto_menu_items AS menu_item
SET image_path = inferred.assets_root || '/menu/combo_individual.png'
FROM inferred_assets_root AS inferred
WHERE menu_item.image_path IS NULL
   OR btrim(menu_item.image_path) = '';
