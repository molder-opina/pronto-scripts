-- Migration: seed package/combo components for canonical combo products.
-- Rollback: optional manual DELETE FROM pronto_menu_package_components WHERE package_item_id IN (...);

-- Paquete Familiar 1: hamburguesas + bebidas (papas se modela como aditamento del paquete).
INSERT INTO pronto_menu_package_components (
    package_item_id,
    component_item_id,
    quantity,
    min_selection,
    max_selection,
    is_required,
    display_order
)
SELECT pkg.id, comp.id, 4, 1, 1, TRUE, 1
FROM pronto_menu_items pkg
JOIN pronto_menu_items comp ON lower(trim(comp.name)) = 'hamburguesa clásica'
WHERE lower(trim(pkg.name)) = 'paquete familiar 1'
ON CONFLICT DO NOTHING;

INSERT INTO pronto_menu_package_components (
    package_item_id,
    component_item_id,
    quantity,
    min_selection,
    max_selection,
    is_required,
    display_order
)
SELECT pkg.id, comp.id, 4, 1, 1, TRUE, 2
FROM pronto_menu_items pkg
JOIN pronto_menu_items comp ON lower(trim(comp.name)) = 'coca-cola'
WHERE lower(trim(pkg.name)) = 'paquete familiar 1'
ON CONFLICT DO NOTHING;

-- Paquete Fiesta Pizza: 2 pizzas + bebida.
INSERT INTO pronto_menu_package_components (
    package_item_id,
    component_item_id,
    quantity,
    min_selection,
    max_selection,
    is_required,
    display_order
)
SELECT pkg.id, comp.id, 1, 1, 1, TRUE, 1
FROM pronto_menu_items pkg
JOIN pronto_menu_items comp ON lower(trim(comp.name)) = 'pizza pepperoni'
WHERE lower(trim(pkg.name)) = 'paquete fiesta pizza'
ON CONFLICT DO NOTHING;

INSERT INTO pronto_menu_package_components (
    package_item_id,
    component_item_id,
    quantity,
    min_selection,
    max_selection,
    is_required,
    display_order
)
SELECT pkg.id, comp.id, 1, 1, 1, TRUE, 2
FROM pronto_menu_items pkg
JOIN pronto_menu_items comp ON lower(trim(comp.name)) = 'pizza margherita'
WHERE lower(trim(pkg.name)) = 'paquete fiesta pizza'
ON CONFLICT DO NOTHING;

INSERT INTO pronto_menu_package_components (
    package_item_id,
    component_item_id,
    quantity,
    min_selection,
    max_selection,
    is_required,
    display_order
)
SELECT pkg.id, comp.id, 1, 1, 1, TRUE, 3
FROM pronto_menu_items pkg
JOIN pronto_menu_items comp ON lower(trim(comp.name)) = 'jugo de naranja'
WHERE lower(trim(pkg.name)) = 'paquete fiesta pizza'
ON CONFLICT DO NOTHING;

-- Paquete Godínez: 5 platillos + 5 bebidas.
INSERT INTO pronto_menu_package_components (
    package_item_id,
    component_item_id,
    quantity,
    min_selection,
    max_selection,
    is_required,
    display_order
)
SELECT pkg.id, comp.id, 3, 1, 1, TRUE, 1
FROM pronto_menu_items pkg
JOIN pronto_menu_items comp ON lower(trim(comp.name)) = 'tacos al pastor'
WHERE lower(trim(pkg.name)) = 'paquete godínez'
ON CONFLICT DO NOTHING;

INSERT INTO pronto_menu_package_components (
    package_item_id,
    component_item_id,
    quantity,
    min_selection,
    max_selection,
    is_required,
    display_order
)
SELECT pkg.id, comp.id, 2, 1, 1, TRUE, 2
FROM pronto_menu_items pkg
JOIN pronto_menu_items comp ON lower(trim(comp.name)) = 'tacos de carnitas'
WHERE lower(trim(pkg.name)) = 'paquete godínez'
ON CONFLICT DO NOTHING;

INSERT INTO pronto_menu_package_components (
    package_item_id,
    component_item_id,
    quantity,
    min_selection,
    max_selection,
    is_required,
    display_order
)
SELECT pkg.id, comp.id, 5, 1, 1, TRUE, 3
FROM pronto_menu_items pkg
JOIN pronto_menu_items comp ON lower(trim(comp.name)) = 'agua mineral'
WHERE lower(trim(pkg.name)) = 'paquete godínez'
ON CONFLICT DO NOTHING;
