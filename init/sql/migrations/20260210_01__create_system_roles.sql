
-- Create system roles table
CREATE TABLE IF NOT EXISTS public.pronto_system_roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(64) NOT NULL UNIQUE,
    display_name VARCHAR(120) NOT NULL,
    description TEXT,
    is_custom BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);

-- Create system permissions table
CREATE TABLE IF NOT EXISTS public.pronto_system_permissions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(64) NOT NULL UNIQUE,
    category VARCHAR(32) NOT NULL,
    description TEXT
);

-- Create bindings table
CREATE TABLE IF NOT EXISTS public.pronto_role_permission_bindings (
    role_id INTEGER NOT NULL REFERENCES pronto_system_roles(id),
    permission_id INTEGER NOT NULL REFERENCES pronto_system_permissions(id),
    PRIMARY KEY (role_id, permission_id)
);

-- Seed default roles
INSERT INTO pronto_system_roles (name, display_name, description, is_custom) VALUES
('admin', 'Administrador', 'Acceso total al sistema', false),
('cashier', 'Cajero', 'Gestión de pagos y caja', false),
('chef', 'Cocina', 'Pantalla de cocina', false),
('waiter', 'Mesero', 'Toma de pedidos', false),
('system', 'Sistema', 'Administración del sistema', false)
ON CONFLICT (name) DO NOTHING;
