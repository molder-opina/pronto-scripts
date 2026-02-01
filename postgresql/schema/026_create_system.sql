-- SuperAdminHandoffToken: Tokens de handoff
CREATE TABLE IF NOT EXISTS super_admin_handoff_tokens (
    id SERIAL PRIMARY KEY,
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    employee_id INTEGER NOT NULL REFERENCES pronto_employees(id),
    target_scope VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE,
    ip_address VARCHAR(45),
    user_agent TEXT
);

CREATE INDEX IF NOT EXISTS ix_handoff_token_hash ON super_admin_handoff_tokens(token_hash);
CREATE INDEX IF NOT EXISTS ix_handoff_expires_at ON super_admin_handoff_tokens(expires_at);

-- AuditLog: Log de auditoría
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES pronto_employees(id),
    action VARCHAR(50) NOT NULL,
    details TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_audit_employee_id ON audit_logs(employee_id);
CREATE INDEX IF NOT EXISTS ix_audit_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS ix_audit_created_at ON audit_logs(created_at);

-- SystemSetting: Configuraciones del sistema
CREATE TABLE IF NOT EXISTS pronto_system_settings (
    key VARCHAR(100) PRIMARY KEY,
    value TEXT NOT NULL,
    value_type VARCHAR(20) NOT NULL DEFAULT 'string',
    description TEXT,
    category VARCHAR(50) NOT NULL DEFAULT 'general',
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
