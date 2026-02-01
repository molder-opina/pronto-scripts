-- Order: Órdenes
CREATE TABLE IF NOT EXISTS pronto_orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES pronto_customers(id),
    customer_email VARCHAR(255),
    session_id INTEGER NOT NULL REFERENCES pronto_dining_sessions(id),
    workflow_status VARCHAR(32) NOT NULL DEFAULT 'new',
    payment_status VARCHAR(32) NOT NULL DEFAULT 'unpaid',
    payment_method VARCHAR(32),
    payment_reference VARCHAR(128),
    payment_meta JSONB,
    notes TEXT,
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    tip_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    waiter_id INTEGER REFERENCES pronto_employees(id),
    chef_id INTEGER REFERENCES pronto_employees(id),
    delivery_waiter_id INTEGER REFERENCES pronto_employees(id),
    accepted_at TIMESTAMP,
    waiter_accepted_at TIMESTAMP,
    chef_accepted_at TIMESTAMP,
    ready_at TIMESTAMP,
    delivered_at TIMESTAMP,
    check_requested_at TIMESTAMP,
    feedback_requested_at TIMESTAMP,
    feedback_completed_at TIMESTAMP,
    paid_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_order_workflow_status ON pronto_orders(workflow_status);
CREATE INDEX IF NOT EXISTS ix_order_status_created ON pronto_orders(workflow_status, created_at);
CREATE INDEX IF NOT EXISTS ix_order_session_id ON pronto_orders(session_id);
CREATE INDEX IF NOT EXISTS ix_order_waiter_id ON pronto_orders(waiter_id);
CREATE INDEX IF NOT EXISTS ix_order_chef_id ON pronto_orders(chef_id);
CREATE INDEX IF NOT EXISTS ix_order_delivery_waiter_id ON pronto_orders(delivery_waiter_id);
CREATE INDEX IF NOT EXISTS ix_order_created_at ON pronto_orders(created_at);

-- OrderItem: Items de orden
CREATE TABLE IF NOT EXISTS pronto_order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES pronto_orders(id),
    menu_item_id INTEGER NOT NULL REFERENCES pronto_menu_items(id),
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price NUMERIC(10, 2) NOT NULL,
    special_instructions TEXT,
    delivered_quantity INTEGER NOT NULL DEFAULT 0,
    is_fully_delivered BOOLEAN NOT NULL DEFAULT FALSE,
    delivered_at TIMESTAMP,
    delivered_by_employee_id INTEGER REFERENCES pronto_employees(id)
);

CREATE INDEX IF NOT EXISTS ix_order_item_order_id ON pronto_order_items(order_id);
CREATE INDEX IF NOT EXISTS ix_order_item_menu_item_id ON pronto_order_items(menu_item_id);
CREATE INDEX IF NOT EXISTS ix_order_item_delivery_status ON pronto_order_items(is_fully_delivered, delivered_at);

-- OrderItemModifier: Modificadores de items
CREATE TABLE IF NOT EXISTS pronto_order_item_modifiers (
    id SERIAL PRIMARY KEY,
    order_item_id INTEGER NOT NULL REFERENCES pronto_order_items(id),
    modifier_id INTEGER NOT NULL REFERENCES pronto_modifiers(id),
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price_adjustment NUMERIC(10, 2) NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS ix_order_item_modifier_item_id ON pronto_order_item_modifiers(order_item_id);
CREATE INDEX IF NOT EXISTS ix_order_item_modifier_modifier_id ON pronto_order_item_modifiers(modifier_id);
