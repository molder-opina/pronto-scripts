-- Migration: backfill QA menu modifier-group links once junction table exists.
-- Rollback: optional manual DELETE FROM pronto_menu_item_modifier_groups WHERE modifier_group_id IN (...);

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