-- Migration: attach canonical modifier groups to combo/package items that include drinks/fries.
-- Rollback: optional manual DELETE in pronto_menu_item_modifier_groups for affected combos.

WITH target_combos AS (
    SELECT id, lower(coalesce(name, '')) AS name_l, lower(coalesce(description, '')) AS desc_l
    FROM pronto_menu_items
    WHERE lower(trim(name)) IN ('paquete familiar 1', 'paquete fiesta pizza', 'paquete godínez')
)
INSERT INTO pronto_menu_item_modifier_groups (menu_item_id, modifier_group_id, display_order)
SELECT tc.id, mg.id, 1
FROM target_combos tc
JOIN pronto_modifier_groups mg ON lower(trim(mg.name)) = 'tamaño de bebida'
WHERE (
    tc.desc_l LIKE '%bebida%'
    OR tc.desc_l LIKE '%refresco%'
)
ON CONFLICT DO NOTHING;

WITH target_combos AS (
    SELECT id, lower(coalesce(name, '')) AS name_l, lower(coalesce(description, '')) AS desc_l
    FROM pronto_menu_items
    WHERE lower(trim(name)) IN ('paquete familiar 1', 'paquete fiesta pizza', 'paquete godínez')
)
INSERT INTO pronto_menu_item_modifier_groups (menu_item_id, modifier_group_id, display_order)
SELECT tc.id, mg.id, 2
FROM target_combos tc
JOIN pronto_modifier_groups mg ON lower(trim(mg.name)) = 'tamaño de papas'
WHERE tc.desc_l LIKE '%papa%'
ON CONFLICT DO NOTHING;
