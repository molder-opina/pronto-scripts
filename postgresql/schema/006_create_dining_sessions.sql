-- DiningSession: Sesiones de comedor
CREATE TABLE IF NOT EXISTS pronto_dining_sessions (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES pronto_customers(id),
    table_id INTEGER REFERENCES pronto_tables(id),
    status VARCHAR(32) NOT NULL DEFAULT 'open',
    table_number VARCHAR(32),
    notes TEXT,
    opened_at TIMESTAMP NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMP,
    expires_at TIMESTAMP,
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    tip_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    total_paid NUMERIC(10, 2) NOT NULL DEFAULT 0,
    payment_method VARCHAR(32),
    payment_reference VARCHAR(128),
    payment_confirmed_at TIMESTAMP,
    tip_requested_at TIMESTAMP,
    tip_confirmed_at TIMESTAMP,
    check_requested_at TIMESTAMP,
    feedback_requested_at TIMESTAMP,
    feedback_completed_at TIMESTAMP,
    email VARCHAR(255)
);

CREATE INDEX IF NOT EXISTS ix_dining_session_status ON pronto_dining_sessions(status);
CREATE INDEX IF NOT EXISTS ix_dining_session_customer_status ON pronto_dining_sessions(customer_id, status);
CREATE INDEX IF NOT EXISTS ix_dining_session_opened_at ON pronto_dining_sessions(opened_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_dining_session_open_table ON pronto_dining_sessions(table_id) WHERE status = 'open';
