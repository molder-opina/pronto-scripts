-- Employee: Empleados
CREATE TABLE IF NOT EXISTS pronto_employees (
    id SERIAL PRIMARY KEY,
    name_encrypted TEXT NOT NULL,
    email_encrypted TEXT NOT NULL,
    email_hash VARCHAR(128) UNIQUE NOT NULL,
    allow_scopes JSONB,
    auth_hash VARCHAR(128) NOT NULL,
    role VARCHAR(64) NOT NULL DEFAULT 'staff',
    additional_roles TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    signed_in_at TIMESTAMP,
    last_activity_at TIMESTAMP,
    preferences JSONB
);

CREATE INDEX IF NOT EXISTS ix_employee_email_hash ON pronto_employees(email_hash);
CREATE INDEX IF NOT EXISTS ix_employee_role_active ON pronto_employees(role, is_active);
CREATE INDEX IF NOT EXISTS ix_employee_created_at ON pronto_employees(created_at);
