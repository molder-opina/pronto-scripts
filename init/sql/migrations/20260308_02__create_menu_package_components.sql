-- Migration: create canonical package/combo components table.
-- Rollback: optional manual DROP TABLE pronto_menu_package_components;

CREATE TABLE IF NOT EXISTS pronto_menu_package_components (
    package_item_id UUID NOT NULL
        REFERENCES pronto_menu_items(id)
        ON DELETE CASCADE,
    component_item_id UUID NOT NULL
        REFERENCES pronto_menu_items(id)
        ON DELETE RESTRICT,
    quantity INTEGER NOT NULL DEFAULT 1
        CHECK (quantity > 0),
    min_selection INTEGER NOT NULL DEFAULT 1,
    max_selection INTEGER NOT NULL DEFAULT 1,
    is_required BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (package_item_id, component_item_id),
    CONSTRAINT chk_package_components_selection_bounds
        CHECK (min_selection >= 0 AND max_selection >= 0 AND min_selection <= max_selection)
);

CREATE INDEX IF NOT EXISTS idx_package_components_package
    ON pronto_menu_package_components(package_item_id, display_order);

CREATE INDEX IF NOT EXISTS idx_package_components_component
    ON pronto_menu_package_components(component_item_id);
