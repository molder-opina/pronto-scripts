#!/usr/bin/env python3
"""Generate UUID seed data for modifier groups."""

import uuid


def gen_uuid(prefix):
    return str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{prefix}.pronto.local"))


# Modifier groups data
groups_data = [
    (
        "mg-burger-001",
        "Size",
        "Choose burger size",
        "a9253e7f-d758-487f-bdcb-464880eb7765",
        0,
        1,
    ),
    (
        "mg-burger-002",
        "Extras",
        "Additional toppings",
        "a9253e7f-d758-487f-bdcb-464880eb7765",
        0,
        5,
    ),
    (
        "mg-burger-003",
        "Cheese",
        "Choose cheese type",
        "a9253e7f-d758-487f-bdcb-464880eb7765",
        0,
        2,
    ),
    (
        "mg-steak-001",
        "Cooking Level",
        "How do you want your steak?",
        "db9be21c-4332-4bed-920f-78991f2f420c",
        1,
        1,
    ),
    (
        "mg-steak-002",
        "Side",
        "Choose side dish",
        "db9be21c-4332-4bed-920f-78991f2f420c",
        1,
        1,
    ),
    (
        "mg-pasta-001",
        "Pasta Type",
        "Choose your pasta",
        "ba2a70fa-48ce-45a8-b8d8-6a4656cf99ad",
        1,
        1,
    ),
    (
        "mg-pasta-002",
        "Add Protein",
        "Add extra protein",
        "ba2a70fa-48ce-45a8-b8d8-6a4656cf99ad",
        0,
        2,
    ),
    (
        "mg-salad-001",
        "Protein",
        "Add protein to your salad",
        "ec7c0797-1119-4c65-abb2-b977b3d413c1",
        0,
        1,
    ),
    (
        "mg-salad-002",
        "Dressing",
        "Choose dressing",
        "ec7c0797-1119-4c65-abb2-b977b3d413c1",
        1,
        1,
    ),
    (
        "mg-tacos-001",
        "Salsa",
        "Choose salsa level",
        "50428772-2803-49f1-9e07-59614437f529",
        0,
        2,
    ),
    (
        "mg-tacos-002",
        "Extras",
        "Additional toppings",
        "50428772-2803-49f1-9e07-59614437f529",
        0,
        3,
    ),
]

# Generate INSERT statements
print("-- Modifier Groups")
for g in groups_data:
    print(
        f"INSERT INTO pronto_modifier_groups (id, name, description, menu_item_id, min_selections, max_selections, is_required, created_at)"
    )
    print(
        f"VALUES ('{gen_uuid(g[0])}', '{g[1]}', '{g[2]}', '{g[3]}', {g[4]}, {g[5]}, false, now())"
    )
    print(f"ON CONFLICT (id) DO NOTHING;")
    print()
