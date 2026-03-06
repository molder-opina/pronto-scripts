-- Migration: create_order_item_modifiers_table
-- Description: Create missing pronto_order_item_modifiers table for order item modifiers
-- Created: 2026-02-15

CREATE TABLE IF NOT EXISTS pronto_order_item_modifiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_item_id UUID NOT NULL REFERENCES pronto_order_items(id) ON DELETE CASCADE,
    modifier_id UUID NOT NULL REFERENCES pronto_modifiers(id),
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price_adjustment NUMERIC(10, 2) NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS ix_order_item_modifier_item_id ON pronto_order_item_modifiers(order_item_id);
CREATE INDEX IF NOT EXISTS ix_order_item_modifier_modifier_id ON pronto_order_item_modifiers(modifier_id);
