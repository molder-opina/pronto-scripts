-- Crear tabla de relación menu_items <-> modifier_groups
-- Esta tabla permite asociar modificadores a productos del menú
-- Fecha: 2026-02-07

-- 1. Crear tabla con primary key compuesta
CREATE TABLE IF NOT EXISTS pronto_menu_item_modifier_groups (
    menu_item_id UUID NOT NULL
        REFERENCES pronto_menu_items(id)
        ON DELETE CASCADE,
    modifier_group_id UUID NOT NULL
        REFERENCES pronto_modifier_groups(id)
        ON DELETE CASCADE,
    display_order INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (menu_item_id, modifier_group_id)
);

-- 2. Índices para mejor rendimiento en queries
CREATE INDEX IF NOT EXISTS idx_menu_item_modifier_groups_menu_item
    ON pronto_menu_item_modifier_groups(menu_item_id);

CREATE INDEX IF NOT EXISTS idx_menu_item_modifier_groups_modifier_group
    ON pronto_menu_item_modifier_groups(modifier_group_id);

-- Comentario para documentación
COMMENT ON TABLE pronto_menu_item_modifier_groups IS
    'Tabla de relación entre productos del menú y grupos de modificadores';
COMMENT ON COLUMN pronto_menu_item_modifier_groups.display_order IS
    'Orden de visualización del grupo de modificadores en el producto';
