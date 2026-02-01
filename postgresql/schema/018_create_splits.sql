-- ProductSchedule: Horarios de productos
CREATE TABLE IF NOT EXISTS pronto_product_schedules (
    id SERIAL PRIMARY KEY,
    menu_item_id INTEGER NOT NULL REFERENCES pronto_menu_items(id),
    day_of_week INTEGER,
    start_time VARCHAR(5),
    end_time VARCHAR(5),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_product_schedule_item ON pronto_product_schedules(menu_item_id);
CREATE INDEX IF NOT EXISTS ix_product_schedule_active ON pronto_product_schedules(is_active);
CREATE INDEX IF NOT EXISTS ix_product_schedule_day_active ON pronto_product_schedules(day_of_week, is_active);

-- SplitBill: División de cuentas
CREATE TABLE IF NOT EXISTS pronto_split_bills (
    id SERIAL PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES pronto_dining_sessions(id),
    split_type VARCHAR(32) NOT NULL DEFAULT 'by_items',
    status VARCHAR(32) NOT NULL DEFAULT 'active',
    number_of_people INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_split_bill_session ON pronto_split_bills(session_id);
CREATE INDEX IF NOT EXISTS ix_split_bill_status ON pronto_split_bills(status);

-- SplitBillPerson: Personas en split
CREATE TABLE IF NOT EXISTS pronto_split_bill_people (
    id SERIAL PRIMARY KEY,
    split_bill_id INTEGER NOT NULL REFERENCES pronto_split_bills(id),
    person_name VARCHAR(100) NOT NULL,
    person_number INTEGER NOT NULL,
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    tip_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    payment_status VARCHAR(32) NOT NULL DEFAULT 'unpaid',
    customer_email VARCHAR(255),
    payment_method VARCHAR(32),
    payment_reference VARCHAR(128),
    paid_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_split_bill_person_split ON pronto_split_bill_people(split_bill_id);

-- SplitBillAssignment: Asignaciones de items
CREATE TABLE IF NOT EXISTS pronto_split_bill_assignments (
    id SERIAL PRIMARY KEY,
    split_bill_id INTEGER NOT NULL REFERENCES pronto_split_bills(id),
    person_id INTEGER NOT NULL REFERENCES pronto_split_bill_people(id),
    order_item_id INTEGER NOT NULL REFERENCES pronto_order_items(id),
    quantity_portion NUMERIC(10, 2) NOT NULL DEFAULT 1.0,
    amount NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_split_assignment_split ON pronto_split_bill_assignments(split_bill_id);
CREATE INDEX IF NOT EXISTS ix_split_assignment_person ON pronto_split_bill_assignments(person_id);
CREATE INDEX IF NOT EXISTS ix_split_assignment_item ON pronto_split_bill_assignments(order_item_id);
