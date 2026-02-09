-- Seed data for modifier groups and modifiers
-- Created: 2026-02-06
-- Purpose: Add modifiers for menu items

-- Burger Modifiers
INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selections, max_selections, is_required, created_at) VALUES
('d1d4839d-e5e3-58dc-96fa-94de4a2568eb', 'Size', 'Choose burger size', 'a9253e7f-d758-487f-bdcb-464880eb7765', 0, 1, false, now()),
('8307f845-d896-51ad-b184-217f270ada6f', 'Extras', 'Additional toppings', 'a9253e7f-d758-487f-bdcb-464880eb7765', 0, 5, false, now()),
('df04d92d-570c-55d1-990b-589c65df74b7', 'Cheese', 'Choose cheese type', 'a9253e7f-d758-487f-bdcb-464880eb7765', 0, 2, false, now())
ON CONFLICT DO NOTHING;

-- Steak Modifiers
INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selections, max_selections, is_required, created_at) VALUES
('d796d2e3-0a41-512c-a687-c2be2901d2c2', 'Cooking Level', 'How do you want your steak?', 'db9be21c-4332-4bed-920f-78991f2f420c', 1, 1, false, now()),
('dfcade41-83fb-51ba-9979-82ac05a58e0d', 'Side', 'Choose side dish', 'db9be21c-4332-4bed-920f-78991f2f420c', 1, 1, false, now())
ON CONFLICT DO NOTHING;

-- Pasta Modifiers
INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selections, max_selections, is_required, created_at) VALUES
('dffbf8cb-0e1b-5e89-9708-e7b8df26adc1', 'Pasta Type', 'Choose your pasta', 'ba2a70fa-48ce-45a8-b8d8-6a4656cf99ad', 1, 1, false, now()),
('5df0ca36-1265-5fb5-bda4-4e2db677747d', 'Add Protein', 'Add extra protein', 'ba2a70fa-48ce-45a8-b8d8-6a4656cf99ad', 0, 2, false, now())
ON CONFLICT DO NOTHING;

-- Salad Modifiers
INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selections, max_selections, is_required, created_at) VALUES
('393b367e-e1c5-5647-bb01-a476f3629f40', 'Protein', 'Add protein to your salad', 'ec7c0797-1119-4c65-abb2-b977b3d413c1', 0, 1, false, now()),
('2a27619a-2823-58de-b1db-e06aa0d93ea8', 'Dressing', 'Choose dressing', 'ec7c0797-1119-4c65-abb2-b977b3d413c1', 1, 1, false, now())
ON CONFLICT DO NOTHING;

-- Taco Modifiers
INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selections, max_selections, is_required, created_at) VALUES
('56116a65-7bd2-5eb2-976a-a255fce63674', 'Salsa', 'Choose salsa level', '50428772-2803-49f1-9e07-59614437f529', 0, 2, false, now()),
('6b4beb78-719b-5ffb-bad2-d31ebd549a33', 'Extras', 'Additional toppings', '50428772-2803-49f1-9e07-59614437f529', 0, 3, false, now())
ON CONFLICT DO NOTHING;

-- Modifiers for Burger Size
INSERT INTO pronto_modifiers (id, group_id, name, price_adjustment, is_available, created_at) VALUES
('c1d4839d-e5e3-58dc-96fa-94de4a2568eb', 'd1d4839d-e5e3-58dc-96fa-94de4a2568eb', 'Single Patty', 0, true, now()),
('8307f845-d896-51ad-b184-217f270ada6f', 'd1d4839d-e5e3-58dc-96fa-94de4a2568eb', 'Double Patty', 3.50, true, now())
ON CONFLICT DO NOTHING;

-- Modifiers for Burger Extras
INSERT INTO pronto_modifiers (id, group_id, name, price_adjustment, is_available, created_at) VALUES
('8307f846-d896-51ad-b184-217f270ada6f', '8307f845-d896-51ad-b184-217f270ada6f', 'Bacon', 1.50, true, now()),
('8307f847-d896-51ad-b184-217f270ada6f', '8307f845-d896-51ad-b184-217f270ada6f', 'Avocado', 1.00, true, now()),
('8307f848-d896-51ad-b184-217f270ada6f', '8307f845-d896-51ad-b184-217f270ada6f', 'Jalapeño', 0.50, true, now()),
('8307f849-d896-51ad-b184-217f270ada6f', '8307f845-d896-51ad-b184-217f270ada6f', 'Fried Egg', 1.25, true, now()),
('8307f850-d896-51ad-b184-217f270ada6f', '8307f845-d896-51ad-b184-217f270ada6f', 'Extra Lettuce', 0, true, now())
ON CONFLICT DO NOTHING;

-- Modifiers for Burger Cheese
INSERT INTO pronto_modifiers (id, group_id, name, price_adjustment, is_available, created_at) VALUES
('df04d92d-570c-55d1-990b-589c65df74b7', 'df04d92d-570c-55d1-990b-589c65df74b7', 'Cheddar', 0, true, now()),
('df04d92e-570c-55d1-990b-589c65df74b7', 'df04d92d-570c-55d1-990b-589c65df74b7', 'Swiss', 0, true, now()),
('df04d92f-570c-55d1-990b-589c65df74b7', 'df04d92d-570c-55d1-990b-589c65df74b7', 'American', 0, true, now()),
('df04d930-570c-55d1-990b-589c65df74b7', 'df04d92d-570c-55d1-990b-589c65df74b7', 'Pepper Jack', 0.50, true, now())
ON CONFLICT DO NOTHING;

-- Modifiers for Steak Cooking Level
INSERT INTO pronto_modifiers (id, group_id, name, price_adjustment, is_available, created_at) VALUES
('d796d2e3-0a41-512c-a687-c2be2901d2c2', 'd796d2e3-0a41-512c-a687-c2be2901d2c2', 'Rare', 0, true, now()),
('d796d2e4-0a41-512c-a687-c2be2901d2c2', 'd796d2e3-0a41-512c-a687-c2be2901d2c2', 'Medium Rare', 0, true, now()),
('d796d2e5-0a41-512c-a687-c2be2901d2c2', 'd796d2e3-0a41-512c-a687-c2be2901d2c2', 'Medium', 0, true, now()),
('d796d2e6-0a41-512c-a687-c2be2901d2c2', 'd796d2e3-0a41-512c-a687-c2be2901d2c2', 'Medium Well', 0, true, now()),
('d796d2e7-0a41-512c-a687-c2be2901d2c2', 'd796d2e3-0a41-512c-a687-c2be2901d2c2', 'Well Done', 0, true, now())
ON CONFLICT DO NOTHING;

-- Modifiers for Steak Side
INSERT INTO pronto_modifiers (id, group_id, name, price_adjustment, is_available, created_at) VALUES
('dfcade41-83fb-51ba-9979-82ac05a58e0d', 'dfcade41-83fb-51ba-9979-82ac05a58e0d', 'French Fries', 0, true, now()),
('dfcade42-83fb-51ba-9979-82ac05a58e0d', 'dfcade41-83fb-51ba-9979-82ac05a58e0d', 'Mashed Potatoes', 0, true, now()),
('dfcade43-83fb-51ba-9979-82ac05a58e0d', 'dfcade41-83fb-51ba-9979-82ac05a58e0d', 'Grilled Vegetables', 0, true, now()),
('dfcade44-83fb-51ba-9979-82ac05a58e0d', 'dfcade41-83fb-51ba-9979-82ac05a58e0d', 'Side Salad', 0, true, now())
ON CONFLICT DO NOTHING;

-- Modifiers for Pasta Type
INSERT INTO pronto_modifiers (id, group_id, name, price_adjustment, is_available, created_at) VALUES
('dffbf8cb-0e1b-5e89-9708-e7b8df26adc1', 'dffbf8cb-0e1b-5e89-9708-e7b8df26adc1', 'Spaghetti', 0, true, now()),
('dffbf8cc-0e1b-5e89-9708-e7b8df26adc1', 'dffbf8cb-0e1b-5e89-9708-e7b8df26adc1', 'Fettuccine', 0, true, now()),
('dffbf8cd-0e1b-5e89-9708-e7b8df26adc1', 'dffbf8cb-0e1b-5e89-9708-e7b8df26adc1', 'Penne', 0, true, now()),
('dffbf8ce-0e1b-5e89-9708-e7b8df26adc1', 'dffbf8cb-0e1b-5e89-9708-e7b8df26adc1', 'Ravioli', 1.50, true, now())
ON CONFLICT DO NOTHING;

-- Modifiers for Pasta Add Protein
INSERT INTO pronto_modifiers (id, group_id, name, price_adjustment, is_available, created_at) VALUES
('5df0ca36-1265-5fb5-bda4-4e2db677747d', '5df0ca36-1265-5fb5-bda4-4e2db677747d', 'Grilled Chicken', 2.50, true, now()),
('5df0ca37-1265-5fb5-bda4-4e2db677747d', '5df0ca36-1265-5fb5-bda4-4e2db677747d', 'Shrimp', 3.50, true, now()),
('5df0ca38-1265-5fb5-bda4-4e2db677747d', '5df0ca36-1265-5fb5-bda4-4e2db677747d', 'Bacon Bits', 1.00, true, now())
ON CONFLICT DO NOTHING;

-- Modifiers for Salad Protein
INSERT INTO pronto_modifiers (id, group_id, name, price_adjustment, is_available, created_at) VALUES
('393b367e-e1c5-5647-bb01-a476f3629f40', '393b367e-e1c5-5647-bb01-a476f3629f40', 'Grilled Chicken', 2.00, true, now()),
('393b367f-e1c5-5647-bb01-a476f3629f40', '393b367e-e1c5-5647-bb01-a476f3629f40', 'Grilled Shrimp', 3.00, true, now()),
('393b3680-e1c5-5647-bb01-a476f3629f40', '393b367e-e1c5-5647-bb01-a476f3629f40', 'Crispy Bacon', 1.50, true, now())
ON CONFLICT DO NOTHING;

-- Modifiers for Salad Dressing
INSERT INTO pronto_modifiers (id, group_id, name, price_adjustment, is_available, created_at) VALUES
('2a27619a-2823-58de-b1db-e06aa0d93ea8', '2a27619a-2823-58de-b1db-e06aa0d93ea8', 'Ranch', 0, true, now()),
('2a27619b-2823-58de-b1db-e06aa0d93ea8', '2a27619a-2823-58de-b1db-e06aa0d93ea8', 'Caesar', 0, true, now()),
('2a27619c-2823-58de-b1db-e06aa0d93ea8', '2a27619a-2823-58de-b1db-e06aa0d93ea8', 'Vinaigrette', 0, true, now()),
('2a27619d-2823-58de-b1db-e06aa0d93ea8', '2a27619a-2823-58de-b1db-e06aa0d93ea8', 'Blue Cheese', 0.50, true, now())
ON CONFLICT DO NOTHING;

-- Modifiers for Taco Salsa
INSERT INTO pronto_modifiers (id, group_id, name, price_adjustment, is_available, created_at) VALUES
('56116a65-7bd2-5eb2-976a-a255fce63674', '56116a65-7bd2-5eb2-976a-a255fce63674', 'Salsa Verde', 0, true, now()),
('56116a66-7bd2-5eb2-976a-a255fce63674', '56116a65-7bd2-5eb2-976a-a255fce63674', 'Salsa Roja', 0, true, now()),
('56116a67-7bd2-5eb2-976a-a255fce63674', '56116a65-7bd2-5eb2-976a-a255fce63674', 'Habanero', 0, true, now()),
('56116a68-7bd2-5eb2-976a-a255fce63674', '56116a65-7bd2-5eb2-976a-a255fce63674', 'No Salsa', 0, true, now())
ON CONFLICT DO NOTHING;

-- Modifiers for Taco Extras
INSERT INTO pronto_modifiers (id, group_id, name, price_adjustment, is_available, created_at) VALUES
('6b4beb78-719b-5ffb-bad2-d31ebd549a33', '6b4beb78-719b-5ffb-bad2-d31ebd549a33', 'Sour Cream', 0, true, now()),
('6b4beb79-719b-5ffb-bad2-d31ebd549a33', '6b4beb78-719b-5ffb-bad2-d31ebd549a33', 'Guacamole', 1.00, true, now()),
('6b4beb80-719b-5ffb-bad2-d31ebd549a33', '6b4beb78-719b-5ffb-bad2-d31ebd549a33', 'Cilantro', 0, true, now()),
('6b4beb81-719b-5ffb-bad2-d31ebd549a33', '6b4beb78-719b-5ffb-bad2-d31ebd549a33', 'Lime Wedges', 0, true, now())
ON CONFLICT DO NOTHING;
