#!/usr/bin/env python3
"""Generate UUID seed data for modifier groups."""

import uuid


def gen_uuid(prefix):
    return str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{prefix}.pronto.local"))


# Modifier groups data
# Demonstrates various min/max selection scenarios for UI testing:
# - Required group with min_selection > 0 (e.g., min=3, max=5)
# - Optional group with min_selection = 0
# - Exact selection group (min = max)
# - Maximum limited optional group
groups_data = [
    (
        "mg-burger-001",
        "Size",
        "Choose burger size (required: select exactly 1)",
        "a9253e7f-d758-487f-bdcb-464880eb7765",
        1,
        1,
    ),
    (
        "mg-burger-002",
        "Extras",
        "Additional toppings (optional: select up to 5)",
        "a9253e7f-d758-487f-bdcb-464880eb7765",
        0,
        5,
    ),
    (
        "mg-burger-003",
        "Cheese",
        "Choose cheese type (optional: select up to 2)",
        "a9253e7f-d758-487f-bdcb-464880eb7765",
        0,
        2,
    ),
    (
        "mg-pizza-001",
        "Toppings",
        "Choose at least 3 toppings for your pizza (required minimum)",
        "db9be21c-4332-4bed-920f-78991f2f420c",
        3,
        5,
    ),
    (
        "mg-pizza-002",
        "Crust",
        "Choose crust type (required: select exactly 1)",
        "db9be21c-4332-4bed-920f-78991f2f420c",
        1,
        1,
    ),
    (
        "mg-pizza-003",
        "Extra Cheese",
        "Add extra cheese (optional: select up to 2)",
        "db9be21c-4332-4bed-920f-78991f2f420c",
        0,
        2,
    ),
    (
        "mg-tacos-001",
        "Salsa",
        "Choose salsa level (required: select at least 1)",
        "50428772-2803-49f1-9e07-59614437f529",
        1,
        3,
    ),
    (
        "mg-tacos-002",
        "Extras",
        "Additional toppings (optional: select up to 3)",
        "50428772-2803-49f1-9e07-59614437f529",
        0,
        3,
    ),
    (
        "mg-salad-001",
        "Greens",
        "Choose at least 2 greens for your salad (required minimum)",
        "ec7c0797-1119-4c65-abb2-b977b3d413c1",
        2,
        4,
    ),
    (
        "mg-salad-002",
        "Protein",
        "Add protein to your salad (optional: select up to 1)",
        "ec7c0797-1119-4c65-abb2-b977b3d413c1",
        0,
        1,
    ),
    (
        "mg-salad-003",
        "Dressing",
        "Choose dressing (required: select exactly 1)",
        "ec7c0797-1119-4c65-abb2-b977b3d413c1",
        1,
        1,
    ),
]

# Generate INSERT statements
print("-- Modifier Groups")
print("-- Demonstrating various min/max selection scenarios for UI testing")
for g in groups_data:
    print(
        f"INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selection, max_selection, is_required, created_at)"
    )
    print(
        f"VALUES ('{gen_uuid(g[0])}', '{g[1]}', '{g[2]}', '{g[3]}', {g[4]}, {g[5]}, {g[4] > 0}, now())"
    )
    print(f"ON CONFLICT (id) DO NOTHING;")
    print()
