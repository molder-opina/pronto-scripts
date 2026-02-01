-- ModifierGroup: Grupos de modificadores
CREATE TABLE IF NOT EXISTS pronto_modifier_groups (
    id SERIAL PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    min_selection INTEGER NOT NULL DEFAULT 0,
    max_selection INTEGER NOT NULL DEFAULT 1,
    is_required BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INTEGER NOT NULL DEFAULT 0
);

-- Modifier: Modificadores individuales
CREATE TABLE IF NOT EXISTS pronto_modifiers (
    id SERIAL PRIMARY KEY,
    group_id INTEGER NOT NULL REFERENCES pronto_modifier_groups(id),
    name VARCHAR(120) NOT NULL,
    price_adjustment NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (price_adjustment >= 0),
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INTEGER NOT NULL DEFAULT 0
);

-- MenuItemModifierGroup: Relación productos-modificadores
CREATE TABLE IF NOT EXISTS pronto_menu_item_modifier_groups (
    menu_item_id INTEGER NOT NULL REFERENCES pronto_menu_items(id),
    modifier_group_id INTEGER NOT NULL REFERENCES pronto_modifier_groups(id),
    display_order INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (menu_item_id, modifier_group_id)
);
