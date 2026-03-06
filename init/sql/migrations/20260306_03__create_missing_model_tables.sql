-- Migration: Create missing tables referenced by ORM models
-- Date: 2026-03-06
-- Description: Creates pronto_product_schedules, pronto_promotions, pronto_invoices,
--              pronto_audit_logs, pronto_super_admin_handoff_tokens

BEGIN;

-- 1. pronto_product_schedules
CREATE TABLE IF NOT EXISTS pronto_product_schedules (
    id SERIAL PRIMARY KEY,
    menu_item_id UUID NOT NULL REFERENCES pronto_menu_items(id),
    day_of_week INTEGER NOT NULL,
    start_time VARCHAR(5) NOT NULL,
    end_time VARCHAR(5) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT uq_product_schedule_item_day UNIQUE (menu_item_id, day_of_week)
);
CREATE INDEX IF NOT EXISTS ix_product_schedule_menu_item ON pronto_product_schedules(menu_item_id);

-- 2. pronto_promotions
CREATE TABLE IF NOT EXISTS pronto_promotions (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    promotion_type VARCHAR(50) NOT NULL DEFAULT 'percentage',
    discount_percentage NUMERIC(5,2),
    discount_amount NUMERIC(10,2),
    valid_from TIMESTAMP WITHOUT TIME ZONE,
    valid_until TIMESTAMP WITHOUT TIME ZONE,
    applies_to VARCHAR(50) NOT NULL DEFAULT 'all',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);

-- 3. pronto_invoices
CREATE TABLE IF NOT EXISTS pronto_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES pronto_customers(id),
    order_id UUID REFERENCES pronto_orders(id),
    dining_session_id UUID REFERENCES pronto_dining_sessions(id),
    facturapi_id VARCHAR(255),
    cfdi_uuid VARCHAR(36) UNIQUE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    subtotal NUMERIC(12,2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    total NUMERIC(12,2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) NOT NULL DEFAULT 'MXN',
    payment_form VARCHAR(2) NOT NULL DEFAULT '03',
    payment_method VARCHAR(3) NOT NULL DEFAULT 'PUE',
    use_cfdi VARCHAR(3) NOT NULL DEFAULT 'G03',
    serie VARCHAR(10),
    folio INTEGER,
    pdf_url TEXT,
    xml_url TEXT,
    email_sent BOOLEAN DEFAULT FALSE,
    email_sent_at TIMESTAMP WITHOUT TIME ZONE,
    email_sent_to VARCHAR(255),
    cancelled BOOLEAN DEFAULT FALSE,
    cancelled_at TIMESTAMP WITHOUT TIME ZONE,
    cancellation_motive VARCHAR(3),
    cancellation_replacement_id UUID,
    error_message TEXT,
    error_details JSONB,
    issued_at TIMESTAMP WITHOUT TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_invoice_customer_id ON pronto_invoices(customer_id);
CREATE INDEX IF NOT EXISTS ix_invoice_order_id ON pronto_invoices(order_id);
CREATE INDEX IF NOT EXISTS ix_invoice_status ON pronto_invoices(status);
CREATE INDEX IF NOT EXISTS ix_invoice_cfdi_uuid ON pronto_invoices(cfdi_uuid);
CREATE INDEX IF NOT EXISTS ix_invoice_created_at ON pronto_invoices(created_at);

-- 4. pronto_audit_logs
CREATE TABLE IF NOT EXISTS pronto_audit_logs (
    id SERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(36) NOT NULL,
    action VARCHAR(50) NOT NULL,
    actor_id UUID REFERENCES pronto_employees(id),
    actor_type VARCHAR(32) NOT NULL,
    old_value JSONB,
    new_value JSONB,
    changed_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_audit_log_entity ON pronto_audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS ix_audit_log_actor ON pronto_audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS ix_audit_log_changed_at ON pronto_audit_logs(changed_at);

-- 5. pronto_super_admin_handoff_tokens
CREATE TABLE IF NOT EXISTS pronto_super_admin_handoff_tokens (
    id SERIAL PRIMARY KEY,
    token VARCHAR(64) NOT NULL UNIQUE,
    employee_id UUID NOT NULL REFERENCES pronto_employees(id),
    expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_handoff_token ON pronto_super_admin_handoff_tokens(token);

COMMIT;
