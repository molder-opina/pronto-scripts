-- Canonical cart persistence tables for customer pre-order buffer.
-- This migration creates DB-backed cart storage aligned with order payload structure.

BEGIN;

CREATE TABLE IF NOT EXISTS pronto_carts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_ref UUID NOT NULL,
    customer_id UUID REFERENCES pronto_customers(id),
    dining_session_id UUID REFERENCES pronto_dining_sessions(id),
    table_id UUID REFERENCES pronto_tables(id),
    table_number VARCHAR(32),
    status VARCHAR(16) NOT NULL DEFAULT 'active',
    notes TEXT,
    submitted_order_id UUID REFERENCES pronto_orders(id),
    submitted_at TIMESTAMPTZ,
    last_submit_meta JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_pronto_carts_status
        CHECK (status IN ('active', 'submitted', 'abandoned'))
);

CREATE TABLE IF NOT EXISTS pronto_cart_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL REFERENCES pronto_carts(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES pronto_menu_items(id),
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    special_instructions TEXT,
    unit_price_snapshot NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    modifiers_snapshot JSONB NOT NULL DEFAULT '[]'::jsonb,
    modifier_none_groups JSONB NOT NULL DEFAULT '[]'::jsonb,
    package_components_snapshot JSONB NOT NULL DEFAULT '[]'::jsonb,
    item_signature VARCHAR(128) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_carts_customer_ref ON pronto_carts(customer_ref);
CREATE INDEX IF NOT EXISTS ix_carts_status ON pronto_carts(status);
CREATE INDEX IF NOT EXISTS ix_carts_created_at ON pronto_carts(created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS ix_carts_active_customer_ref
    ON pronto_carts(customer_ref) WHERE status = 'active';

CREATE INDEX IF NOT EXISTS ix_cart_items_cart_id ON pronto_cart_items(cart_id);
CREATE UNIQUE INDEX IF NOT EXISTS ix_cart_items_signature
    ON pronto_cart_items(cart_id, item_signature);

COMMIT;
