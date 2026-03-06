-- QA menu seed canonicalized in INIT (not runtime python seeding).
-- Ensures: categories/items coverage, modifiers/add-ons, combo package options,
-- and quick-serve vs prep-required mix for client flow testing.

-- 1) Ensure one category per required type (respecting existing ES/EN aliases)
INSERT INTO pronto_menu_categories (id, name, description, display_order, is_active)
SELECT '11111111-1111-1111-1111-111111111101'::uuid, 'Entradas', 'Entradas para compartir', 10, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM pronto_menu_categories WHERE lower(trim(name)) IN ('entradas', 'appetizers', 'starters')
)
ON CONFLICT DO NOTHING;

INSERT INTO pronto_menu_categories (id, name, description, display_order, is_active)
SELECT '11111111-1111-1111-1111-111111111102'::uuid, 'Bebidas', 'Bebidas frías y calientes', 20, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM pronto_menu_categories WHERE lower(trim(name)) IN ('bebidas', 'beverages', 'drinks')
)
ON CONFLICT DO NOTHING;

INSERT INTO pronto_menu_categories (id, name, description, display_order, is_active)
SELECT '11111111-1111-1111-1111-111111111103'::uuid, 'Combos', 'Paquetes listos para ordenar', 30, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM pronto_menu_categories WHERE lower(trim(name)) IN ('combos', 'combo')
)
ON CONFLICT DO NOTHING;

INSERT INTO pronto_menu_categories (id, name, description, display_order, is_active)
SELECT '11111111-1111-1111-1111-111111111104'::uuid, 'Platos fuertes', 'Preparaciones principales', 40, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM pronto_menu_categories WHERE lower(trim(name)) IN ('platos fuertes', 'main courses', 'main_course')
)
ON CONFLICT DO NOTHING;

INSERT INTO pronto_menu_categories (id, name, description, display_order, is_active)
SELECT '11111111-1111-1111-1111-111111111105'::uuid, 'Postres', 'Postres para cerrar', 50, TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM pronto_menu_categories WHERE lower(trim(name)) IN ('postres', 'desserts')
)
ON CONFLICT DO NOTHING;

WITH category_candidates AS (
  SELECT
    id,
    display_order,
    name,
    CASE
      WHEN lower(trim(name)) IN ('entradas', 'appetizers', 'starters') THEN 'appetizers'
      WHEN lower(trim(name)) IN ('bebidas', 'beverages', 'drinks') THEN 'beverages'
      WHEN lower(trim(name)) IN ('combos', 'combo') THEN 'combos'
      WHEN lower(trim(name)) IN ('platos fuertes', 'main courses', 'main_course') THEN 'main_courses'
      WHEN lower(trim(name)) IN ('postres', 'desserts') THEN 'desserts'
      ELSE NULL
    END AS bucket
  FROM pronto_menu_categories
),
resolved_categories AS (
  SELECT DISTINCT ON (bucket) bucket, id
  FROM category_candidates
  WHERE bucket IS NOT NULL
  ORDER BY bucket, display_order ASC, name ASC
)
-- 2) Ensure QA items (>=3 per type) with deterministic IDs
INSERT INTO pronto_menu_items (
  id, category_id, name, description, price, image_path, is_available,
  preparation_time_minutes, is_quick_serve
)
SELECT item_id, rc.id, item_name, item_description, item_price, item_image, TRUE, prep_minutes, quick_serve
FROM (
  VALUES
    -- Entradas
    ('22222222-2222-2222-2222-222222222101'::uuid, 'appetizers', 'Crispy Calamari', 'Calamares fritos con salsa tártara', 12.99::numeric, '/assets/pronto/menu/crispy_calamari.png', 10, FALSE),
    ('22222222-2222-2222-2222-222222222102'::uuid, 'appetizers', 'Bruschetta', 'Pan tostado con tomate, albahaca y aceite de oliva', 9.99::numeric, '/assets/pronto/menu/bruschetta.png', 8, FALSE),
    ('22222222-2222-2222-2222-222222222103'::uuid, 'appetizers', 'Caesar Salad', 'Lechuga romana, croutones y parmesano', 11.99::numeric, '/assets/pronto/menu/caesar_salad.png', 7, FALSE),
    -- Bebidas (rápidas)
    ('22222222-2222-2222-2222-222222222201'::uuid, 'beverages', 'Café Americano', 'Café recién preparado', 25.00::numeric, '/assets/pronto/menu/cafe_americano.png', 4, TRUE),
    ('22222222-2222-2222-2222-222222222202'::uuid, 'beverages', 'Café Espresso', 'Café espresso italiano', 35.00::numeric, '/assets/pronto/menu/cafe_espresso.png', 4, TRUE),
    ('22222222-2222-2222-2222-222222222203'::uuid, 'beverages', 'Agua Mineral', 'Agua mineral fría', 15.00::numeric, '/assets/pronto/menu/agua_mineral.png', 2, TRUE),
    -- Combos (paquetes)
    ('22222222-2222-2222-2222-222222222301'::uuid, 'combos', 'Combo Express', 'Incluye plato, bebida y guarnición', 21.13::numeric, '/assets/pronto/menu/combo_express.png', 12, FALSE),
    ('22222222-2222-2222-2222-222222222302'::uuid, 'combos', 'Combo Doble', '2 platos base + bebida y guarnición', 28.50::numeric, '/assets/pronto/menu/combo_doble.png', 14, FALSE),
    ('22222222-2222-2222-2222-222222222303'::uuid, 'combos', 'Combo Familiar', 'Paquete familiar con extras', 34.90::numeric, '/assets/pronto/menu/combos_familiar.png', 16, FALSE),
    -- Platos fuertes
    ('22222222-2222-2222-2222-222222222401'::uuid, 'main_courses', 'Grilled Chicken Burger', 'Pollo a la parrilla con vegetales', 14.99::numeric, '/assets/pronto/menu/grilled_chicken.png', 15, FALSE),
    ('22222222-2222-2222-2222-222222222402'::uuid, 'main_courses', 'Beef Steak', 'Corte de res con guarnición', 24.99::numeric, '/assets/pronto/menu/beef_steak.png', 20, FALSE),
    ('22222222-2222-2222-2222-222222222403'::uuid, 'main_courses', 'Fish Tacos', 'Tacos de pescado con salsa de mango', 13.99::numeric, '/assets/pronto/menu/fish_tacos.png', 12, FALSE),
    -- Postres (algunos rápidos)
    ('22222222-2222-2222-2222-222222222501'::uuid, 'desserts', 'Chocolate Lava Cake', 'Pastel de chocolate con centro fundido', 8.99::numeric, '/assets/pronto/menu/chocolate_lava_cake.png', 12, FALSE),
    ('22222222-2222-2222-2222-222222222502'::uuid, 'desserts', 'Cheesecake', 'Cheesecake de fresa', 7.99::numeric, '/assets/pronto/menu/cheesecake.png', 3, TRUE),
    ('22222222-2222-2222-2222-222222222503'::uuid, 'desserts', 'Ice Cream', 'Helado de vainilla o chocolate', 4.99::numeric, '/assets/pronto/menu/ice_cream.png', 2, TRUE)
) AS items(item_id, bucket, item_name, item_description, item_price, item_image, prep_minutes, quick_serve)
JOIN resolved_categories rc ON rc.bucket = items.bucket
WHERE NOT EXISTS (
  SELECT 1
  FROM pronto_menu_items mi
  WHERE lower(trim(mi.name)) = lower(trim(items.item_name))
    AND mi.category_id = rc.id
)
ON CONFLICT DO NOTHING;

-- 3) Modifier groups for add-ons and combo package options
INSERT INTO pronto_modifier_groups (id, name, description, min_select, max_select, is_required, display_order)
VALUES
  ('33333333-3333-3333-3333-333333333001'::uuid, 'Aditamientos base QA', 'Extras para personalización', 0, 3, FALSE, 90),
  ('33333333-3333-3333-3333-333333333002'::uuid, 'Paquete QA: Bebida incluida', 'Selecciona la bebida incluida del paquete', 1, 1, TRUE, 91),
  ('33333333-3333-3333-3333-333333333003'::uuid, 'Paquete QA: Guarnición incluida', 'Selecciona la guarnición incluida del paquete', 1, 1, TRUE, 92)
ON CONFLICT DO NOTHING;

INSERT INTO pronto_modifiers (id, group_id, name, price_adjustment, is_available, display_order)
VALUES
  -- Aditamientos base
  ('44444444-4444-4444-4444-444444444001'::uuid, '33333333-3333-3333-3333-333333333001'::uuid, 'Queso extra', 10.00, TRUE, 1),
  ('44444444-4444-4444-4444-444444444002'::uuid, '33333333-3333-3333-3333-333333333001'::uuid, 'Bacon', 15.00, TRUE, 2),
  ('44444444-4444-4444-4444-444444444003'::uuid, '33333333-3333-3333-3333-333333333001'::uuid, 'Aguacate', 12.00, TRUE, 3),
  -- Opciones bebida paquete
  ('44444444-4444-4444-4444-444444444011'::uuid, '33333333-3333-3333-3333-333333333002'::uuid, 'Café Americano', 0.00, TRUE, 1),
  ('44444444-4444-4444-4444-444444444012'::uuid, '33333333-3333-3333-3333-333333333002'::uuid, 'Café Espresso', 0.00, TRUE, 2),
  ('44444444-4444-4444-4444-444444444013'::uuid, '33333333-3333-3333-3333-333333333002'::uuid, 'Agua Mineral', 0.00, TRUE, 3),
  -- Opciones guarnición paquete
  ('44444444-4444-4444-4444-444444444021'::uuid, '33333333-3333-3333-3333-333333333003'::uuid, 'Papas regulares', 0.00, TRUE, 1),
  ('44444444-4444-4444-4444-444444444022'::uuid, '33333333-3333-3333-3333-333333333003'::uuid, 'Ensalada', 0.00, TRUE, 2),
  ('44444444-4444-4444-4444-444444444023'::uuid, '33333333-3333-3333-3333-333333333003'::uuid, 'Aros de cebolla', 0.00, TRUE, 3)
ON CONFLICT DO NOTHING;

-- 4) Link aditamientos to non-combo QA items
INSERT INTO pronto_menu_item_modifier_groups (menu_item_id, modifier_group_id, display_order)
SELECT mi.id, '33333333-3333-3333-3333-333333333001'::uuid, 1
FROM pronto_menu_items mi
WHERE lower(trim(mi.name)) IN (
  'crispy calamari',
  'bruschetta',
  'caesar salad',
  'grilled chicken burger',
  'beef steak',
  'fish tacos'
)
ON CONFLICT DO NOTHING;

-- 5) Link combo package options (bebida + guarnición) to combo QA items
INSERT INTO pronto_menu_item_modifier_groups (menu_item_id, modifier_group_id, display_order)
SELECT mi.id, '33333333-3333-3333-3333-333333333002'::uuid, 1
FROM pronto_menu_items mi
WHERE lower(trim(mi.name)) IN ('combo express', 'combo doble', 'combo familiar')
ON CONFLICT DO NOTHING;

INSERT INTO pronto_menu_item_modifier_groups (menu_item_id, modifier_group_id, display_order)
SELECT mi.id, '33333333-3333-3333-3333-333333333003'::uuid, 2
FROM pronto_menu_items mi
WHERE lower(trim(mi.name)) IN ('combo express', 'combo doble', 'combo familiar')
ON CONFLICT DO NOTHING;
