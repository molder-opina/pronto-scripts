-- CustomRole: Roles personalizados
CREATE TABLE IF NOT EXISTS pronto_custom_roles (
    id SERIAL PRIMARY KEY,
    role_code VARCHAR(64) NOT NULL UNIQUE,
    role_name VARCHAR(100) NOT NULL,
    description TEXT,
    color VARCHAR(20),
    icon VARCHAR(50),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by INTEGER REFERENCES pronto_employees(id)
);

CREATE INDEX IF NOT EXISTS ix_custom_role_code ON pronto_custom_roles(role_code);
CREATE INDEX IF NOT EXISTS ix_custom_role_active ON pronto_custom_roles(is_active);

-- RolePermission: Permisos de roles personalizados
CREATE TABLE IF NOT EXISTS pronto_role_permissions (
    id SERIAL PRIMARY KEY,
    custom_role_id INTEGER NOT NULL REFERENCES pronto_custom_roles(id),
    resource_type VARCHAR(50) NOT NULL,
    action VARCHAR(50) NOT NULL,
    allowed BOOLEAN NOT NULL DEFAULT TRUE,
    conditions TEXT
);

CREATE INDEX IF NOT EXISTS ix_role_permission_role ON pronto_role_permissions(custom_role_id);
CREATE INDEX IF NOT EXISTS ix_role_permission_resource ON pronto_role_permissions(resource_type, action);
