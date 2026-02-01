-- SystemRole: Roles del sistema
CREATE TABLE IF NOT EXISTS pronto_system_roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(64) NOT NULL UNIQUE,
    display_name VARCHAR(120) NOT NULL,
    description TEXT,
    is_custom BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- SystemPermission: Permisos del sistema
CREATE TABLE IF NOT EXISTS pronto_system_permissions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(64) NOT NULL UNIQUE,
    category VARCHAR(32) NOT NULL,
    description TEXT
);

-- RolePermissionBinding: Vinculación rol-permiso
CREATE TABLE IF NOT EXISTS pronto_role_permission_bindings (
    role_id INTEGER NOT NULL REFERENCES pronto_system_roles(id),
    permission_id INTEGER NOT NULL REFERENCES pronto_system_permissions(id),
    PRIMARY KEY (role_id, permission_id)
);
