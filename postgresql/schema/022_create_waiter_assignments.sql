-- WaiterTableAssignment: Asignación meseros-mesas
CREATE TABLE IF NOT EXISTS pronto_waiter_table_assignments (
    id SERIAL PRIMARY KEY,
    waiter_id INTEGER NOT NULL REFERENCES pronto_employees(id),
    table_id INTEGER NOT NULL REFERENCES pronto_tables(id),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    assigned_at TIMESTAMP NOT NULL DEFAULT NOW(),
    unassigned_at TIMESTAMP,
    notes TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_waiter_table_active ON pronto_waiter_table_assignments(waiter_id, table_id) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS ix_waiter_table_assignment_waiter ON pronto_waiter_table_assignments(waiter_id);
CREATE INDEX IF NOT EXISTS ix_waiter_table_assignment_table ON pronto_waiter_table_assignments(table_id);
CREATE INDEX IF NOT EXISTS ix_waiter_table_assignment_active ON pronto_waiter_table_assignments(is_active);

-- TableTransferRequest: Transferencias de mesa
CREATE TABLE IF NOT EXISTS pronto_table_transfer_requests (
    id SERIAL PRIMARY KEY,
    table_id INTEGER NOT NULL REFERENCES pronto_tables(id),
    from_waiter_id INTEGER NOT NULL REFERENCES pronto_employees(id),
    to_waiter_id INTEGER NOT NULL REFERENCES pronto_employees(id),
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    transfer_orders BOOLEAN NOT NULL DEFAULT FALSE,
    message TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMP,
    resolved_by_employee_id INTEGER REFERENCES pronto_employees(id)
);

CREATE INDEX IF NOT EXISTS ix_table_transfer_from_waiter ON pronto_table_transfer_requests(from_waiter_id);
CREATE INDEX IF NOT EXISTS ix_table_transfer_to_waiter ON pronto_table_transfer_requests(to_waiter_id);
CREATE INDEX IF NOT EXISTS ix_table_transfer_table ON pronto_table_transfer_requests(table_id);
CREATE INDEX IF NOT EXISTS ix_table_transfer_status ON pronto_table_transfer_requests(status);
CREATE INDEX IF NOT EXISTS ix_table_transfer_created ON pronto_table_transfer_requests(created_at);
