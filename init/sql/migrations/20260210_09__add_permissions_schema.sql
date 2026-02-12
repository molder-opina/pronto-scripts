-- Create permissions tables

CREATE TABLE IF NOT EXISTS pronto_route_permissions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(64) UNIQUE NOT NULL,
    description TEXT,
    display_name VARCHAR(120) NOT NULL,
    app_target VARCHAR(32) NOT NULL
);

CREATE TABLE IF NOT EXISTS pronto_employee_route_access (
    employee_id UUID NOT NULL REFERENCES pronto_employees(id),
    route_permission_id INTEGER NOT NULL REFERENCES pronto_route_permissions(id),
    granted_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    PRIMARY KEY (employee_id, route_permission_id)
);

-- Seed basic permissions if needed (optional)
INSERT INTO pronto_route_permissions (code, display_name, app_target) VALUES 
('waiter-board', 'Waiter Dashboard', 'employee')
ON CONFLICT (code) DO NOTHING;
