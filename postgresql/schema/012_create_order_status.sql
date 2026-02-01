-- OrderStatusHistory: Historial de estados
CREATE TABLE IF NOT EXISTS pronto_order_status_history (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES pronto_orders(id),
    status VARCHAR(32) NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- OrderStatusLabel: Etiquetas de estado editables
CREATE TABLE IF NOT EXISTS pronto_order_status_labels (
    status_key VARCHAR(32) PRIMARY KEY,
    client_label VARCHAR(120) NOT NULL,
    employee_label VARCHAR(120) NOT NULL,
    admin_desc TEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_by_emp_id INTEGER REFERENCES pronto_employees(id),
    version INTEGER NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_order_status_label_key ON pronto_order_status_labels(status_key);

-- OrderModification: Modificaciones de órdenes
CREATE TABLE IF NOT EXISTS pronto_order_modifications (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES pronto_orders(id),
    initiated_by_role VARCHAR(32) NOT NULL,
    initiated_by_customer_id INTEGER REFERENCES pronto_customers(id),
    initiated_by_employee_id INTEGER REFERENCES pronto_employees(id),
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    changes_data JSONB NOT NULL DEFAULT '{}',
    reviewed_by_customer_id INTEGER REFERENCES pronto_customers(id),
    reviewed_by_employee_id INTEGER REFERENCES pronto_employees(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    reviewed_at TIMESTAMP,
    applied_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_order_modification_order ON pronto_order_modifications(order_id);
CREATE INDEX IF NOT EXISTS ix_order_modification_status ON pronto_order_modifications(status);
CREATE INDEX IF NOT EXISTS ix_order_modification_created_at ON pronto_order_modifications(created_at);
