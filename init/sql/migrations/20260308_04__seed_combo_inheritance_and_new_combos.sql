-- Migration: create 3 canonical test combos, seed package components, and backfill inherited modifier groups.
-- Rollback: optional manual DELETE on combo names and related rows in pronto_menu_package_components/pronto_menu_item_modifier_groups.

WITH combos_category AS (
    SELECT c.id AS category_id
    FROM pronto_menu_categories c
    WHERE lower(trim(c.name)) = 'combos'
    LIMIT 1
),
combos_subcategory AS (
    SELECT s.id AS subcategory_id
    FROM pronto_menu_subcategories s
    JOIN combos_category cc ON s.menu_category_id = cc.category_id
    ORDER BY s.sort_order, s.name
    LIMIT 1
)
INSERT INTO pronto_menu_items (
    category_id,
    menu_category_id,
    menu_subcategory_id,
    item_kind,
    name,
    description,
    price,
    image_path,
    is_available,
    is_active,
    sort_order,
    display_order,
    preparation_time_minutes
)
SELECT
    cc.category_id,
    cc.category_id,
    cs.subcategory_id,
    src.item_kind,
    src.name,
    src.description,
    src.price,
    COALESCE(
        (
            SELECT ref_item.image_path
            FROM pronto_menu_items ref_item
            WHERE lower(trim(ref_item.name)) = lower(trim(src.image_ref_name))
              AND ref_item.image_path IS NOT NULL
              AND trim(ref_item.image_path) <> ''
            LIMIT 1
        ),
        src.default_image_path
    ) AS image_path,
    TRUE,
    TRUE,
    src.sort_order,
    src.sort_order,
    src.preparation_time_minutes
FROM combos_category cc
LEFT JOIN combos_subcategory cs ON TRUE
JOIN (
    VALUES
        (
            'combo'::varchar,
            'Combo Clásico Lunch'::varchar,
            'Incluye hamburguesa clásica + refresco + papas. Personaliza tus extras.'::text,
            14.99::numeric,
            'Hamburguesa Clásica'::varchar,
            '/assets/pronto/menu/combo_individual.png'::varchar,
            810::int,
            20::int
        ),
        (
            'combo'::varchar,
            'Combo Pizza Refresco'::varchar,
            'Incluye pizza pepperoni + bebida. Agrega queso y ajusta tamaño.'::text,
            19.99::numeric,
            'Pizza Pepperoni'::varchar,
            '/assets/pronto/menu/combo_pizza.png'::varchar,
            811::int,
            24::int
        ),
        (
            'combo'::varchar,
            'Combo Tacos Frescos'::varchar,
            'Incluye tacos al pastor + jugo natural. Ajusta salsas y bebida.'::text,
            12.99::numeric,
            'Tacos al Pastor'::varchar,
            '/assets/pronto/menu/combo_tacos.png'::varchar,
            812::int,
            18::int
        )
) AS src(
    item_kind,
    name,
    description,
    price,
    image_ref_name,
    default_image_path,
    sort_order,
    preparation_time_minutes
)
ON TRUE
WHERE cc.category_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM pronto_menu_items mi
      WHERE lower(trim(mi.name)) = lower(trim(src.name))
  );

WITH combo_components AS (
    SELECT
        lower(trim(combo_name)) AS combo_name,
        lower(trim(component_name)) AS component_name,
        quantity,
        min_selection,
        max_selection,
        is_required,
        display_order
    FROM (
        VALUES
            ('Paquete Familiar 1', 'Hamburguesa Clásica', 4, 1, 1, TRUE, 1),
            ('Paquete Familiar 1', 'Coca-Cola', 4, 1, 1, TRUE, 2),
            ('Paquete Fiesta Pizza', 'Pizza Pepperoni', 1, 1, 1, TRUE, 1),
            ('Paquete Fiesta Pizza', 'Pizza Margherita', 1, 1, 1, TRUE, 2),
            ('Paquete Fiesta Pizza', 'Jugo de Naranja', 1, 1, 1, TRUE, 3),
            ('Paquete Godínez', 'Tacos al Pastor', 3, 1, 1, TRUE, 1),
            ('Paquete Godínez', 'Tacos de Carnitas', 2, 1, 1, TRUE, 2),
            ('Paquete Godínez', 'Agua Mineral', 5, 1, 1, TRUE, 3),
            ('Combo Clásico Lunch', 'Hamburguesa Clásica', 1, 1, 1, TRUE, 1),
            ('Combo Clásico Lunch', 'Coca-Cola', 1, 1, 1, TRUE, 2),
            ('Combo Pizza Refresco', 'Pizza Pepperoni', 1, 1, 1, TRUE, 1),
            ('Combo Pizza Refresco', 'Agua Mineral', 1, 1, 1, TRUE, 2),
            ('Combo Tacos Frescos', 'Tacos al Pastor', 1, 1, 1, TRUE, 1),
            ('Combo Tacos Frescos', 'Jugo de Naranja', 1, 1, 1, TRUE, 2)
    ) AS t(combo_name, component_name, quantity, min_selection, max_selection, is_required, display_order)
)
INSERT INTO pronto_menu_package_components (
    package_item_id,
    component_item_id,
    quantity,
    min_selection,
    max_selection,
    is_required,
    display_order
)
SELECT
    combo.id,
    component.id,
    cc.quantity,
    cc.min_selection,
    cc.max_selection,
    cc.is_required,
    cc.display_order
FROM combo_components cc
JOIN pronto_menu_items combo
  ON lower(trim(combo.name)) = cc.combo_name
JOIN pronto_menu_items component
  ON lower(trim(component.name)) = cc.component_name
ON CONFLICT (package_item_id, component_item_id)
DO UPDATE SET
    quantity = EXCLUDED.quantity,
    min_selection = EXCLUDED.min_selection,
    max_selection = EXCLUDED.max_selection,
    is_required = EXCLUDED.is_required,
    display_order = EXCLUDED.display_order;

WITH combo_specific_groups AS (
    SELECT
        lower(trim(combo_name)) AS combo_name,
        lower(trim(group_name)) AS group_name,
        display_order
    FROM (
        VALUES
            ('Paquete Familiar 1', 'Tamaño de Bebida', 1),
            ('Paquete Familiar 1', 'Tamaño de Papas', 2),
            ('Paquete Familiar 1', 'Salsas', 3),
            ('Paquete Fiesta Pizza', 'Tamaño de Bebida', 1),
            ('Paquete Fiesta Pizza', 'Queso Extra', 2),
            ('Paquete Godínez', 'Tamaño de Bebida', 1),
            ('Paquete Godínez', 'Salsas', 2),
            ('Combo Clásico Lunch', 'Tamaño de Bebida', 1),
            ('Combo Clásico Lunch', 'Tamaño de Papas', 2),
            ('Combo Clásico Lunch', 'Salsas', 3),
            ('Combo Pizza Refresco', 'Tamaño de Bebida', 1),
            ('Combo Pizza Refresco', 'Queso Extra', 2),
            ('Combo Tacos Frescos', 'Tamaño de Bebida', 1),
            ('Combo Tacos Frescos', 'Salsas', 2)
    ) AS t(combo_name, group_name, display_order)
)
INSERT INTO pronto_menu_item_modifier_groups (menu_item_id, modifier_group_id, display_order)
SELECT
    combo.id,
    mg.id,
    csg.display_order
FROM combo_specific_groups csg
JOIN pronto_menu_items combo
  ON lower(trim(combo.name)) = csg.combo_name
JOIN pronto_modifier_groups mg
  ON lower(trim(mg.name)) = csg.group_name
ON CONFLICT DO NOTHING;

WITH inherited_links AS (
    SELECT
        pc.package_item_id AS combo_id,
        mig.modifier_group_id AS group_id,
        MIN(mig.display_order) AS source_order
    FROM pronto_menu_package_components pc
    JOIN pronto_menu_item_modifier_groups mig
      ON mig.menu_item_id = pc.component_item_id
    GROUP BY pc.package_item_id, mig.modifier_group_id
)
INSERT INTO pronto_menu_item_modifier_groups (menu_item_id, modifier_group_id, display_order)
SELECT
    il.combo_id,
    il.group_id,
    100 + ROW_NUMBER() OVER (
        PARTITION BY il.combo_id
        ORDER BY il.source_order, il.group_id
    )
FROM inherited_links il
ON CONFLICT DO NOTHING;
