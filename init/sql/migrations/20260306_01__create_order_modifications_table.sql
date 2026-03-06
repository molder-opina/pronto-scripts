-- Ensure canonical order modifications table exists for modification workflow tests/runtime

CREATE TABLE IF NOT EXISTS pronto_order_modifications (
    id SERIAL PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES pronto_orders(id),
    initiated_by_role VARCHAR(32) NOT NULL,
    initiated_by_customer_id UUID NULL REFERENCES pronto_customers(id),
    initiated_by_employee_id UUID NULL REFERENCES pronto_employees(id),
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    changes_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    reviewed_by_customer_id UUID NULL REFERENCES pronto_customers(id),
    reviewed_by_employee_id UUID NULL REFERENCES pronto_employees(id),
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMP WITHOUT TIME ZONE NULL,
    applied_at TIMESTAMP WITHOUT TIME ZONE NULL
);

CREATE INDEX IF NOT EXISTS ix_order_modification_order
    ON pronto_order_modifications (order_id);

CREATE INDEX IF NOT EXISTS ix_order_modification_status
    ON pronto_order_modifications (status);

CREATE INDEX IF NOT EXISTS ix_order_modification_created_at
    ON pronto_order_modifications (created_at);
