-- WaiterCall: Llamadas de mesero
CREATE TABLE IF NOT EXISTS pronto_waiter_calls (
    id SERIAL PRIMARY KEY,
    session_id INTEGER REFERENCES pronto_dining_sessions(id),
    table_number VARCHAR(32),
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    confirmed_at TIMESTAMP,
    confirmed_by INTEGER REFERENCES pronto_employees(id),
    cancelled_at TIMESTAMP,
    notes TEXT
);

CREATE INDEX IF NOT EXISTS ix_waiter_call_session ON pronto_waiter_calls(session_id);
CREATE INDEX IF NOT EXISTS ix_waiter_call_status ON pronto_waiter_calls(status);
CREATE INDEX IF NOT EXISTS ix_waiter_call_created_at ON pronto_waiter_calls(created_at);
CREATE INDEX IF NOT EXISTS ix_waiter_call_confirmed_by ON pronto_waiter_calls(confirmed_by);
