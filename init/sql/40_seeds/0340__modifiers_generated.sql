-- Modifier Groups
-- Demonstrating various min/max selection scenarios for UI testing
INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selection, max_selection, is_required, created_at)
VALUES ('d1d4839d-e5e3-58dc-96fa-94de4a2568eb', 'Size', 'Choose burger size (required: select exactly 1)', 'a9253e7f-d758-487f-bdcb-464880eb7765', 1, 1, True, now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selection, max_selection, is_required, created_at)
VALUES ('8307f845-d896-51ad-b184-217f270ada6f', 'Extras', 'Additional toppings (optional: select up to 5)', 'a9253e7f-d758-487f-bdcb-464880eb7765', 0, 5, False, now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selection, max_selection, is_required, created_at)
VALUES ('df04d92d-570c-55d1-990b-589c65df74b7', 'Cheese', 'Choose cheese type (optional: select up to 2)', 'a9253e7f-d758-487f-bdcb-464880eb7765', 0, 2, False, now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selection, max_selection, is_required, created_at)
VALUES ('c25d5ad9-3ba8-5351-bcbd-f8a6b354de43', 'Toppings', 'Choose at least 3 toppings for your pizza (required minimum)', 'db9be21c-4332-4bed-920f-78991f2f420c', 3, 5, True, now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selection, max_selection, is_required, created_at)
VALUES ('8e1f3dce-8f24-5a37-b005-1ce0a4e952ea', 'Crust', 'Choose crust type (required: select exactly 1)', 'db9be21c-4332-4bed-920f-78991f2f420c', 1, 1, True, now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selection, max_selection, is_required, created_at)
VALUES ('43d3a37c-23a1-53b0-bb4f-56f75d16c049', 'Extra Cheese', 'Add extra cheese (optional: select up to 2)', 'db9be21c-4332-4bed-920f-78991f2f420c', 0, 2, False, now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selection, max_selection, is_required, created_at)
VALUES ('56116a65-7bd2-5eb2-976a-a255fce63674', 'Salsa', 'Choose salsa level (required: select at least 1)', '50428772-2803-49f1-9e07-59614437f529', 1, 3, True, now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selection, max_selection, is_required, created_at)
VALUES ('6b4beb78-719b-5ffb-bad2-d31ebd549a33', 'Extras', 'Additional toppings (optional: select up to 3)', '50428772-2803-49f1-9e07-59614437f529', 0, 3, False, now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selection, max_selection, is_required, created_at)
VALUES ('393b367e-e1c5-5647-bb01-a476f3629f40', 'Greens', 'Choose at least 2 greens for your salad (required minimum)', 'ec7c0797-1119-4c65-abb2-b977b3d413c1', 2, 4, True, now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selection, max_selection, is_required, created_at)
VALUES ('2a27619a-2823-58de-b1db-e06aa0d93ea8', 'Protein', 'Add protein to your salad (optional: select up to 1)', 'ec7c0797-1119-4c65-abb2-b977b3d413c1', 0, 1, False, now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selection, max_selection, is_required, created_at)
VALUES ('37e1d397-3d92-5f45-9cc0-115483a949ac', 'Dressing', 'Choose dressing (required: select exactly 1)', 'ec7c0797-1119-4c65-abb2-b977b3d413c1', 1, 1, True, now())
ON CONFLICT (id) DO NOTHING;

