-- RoutePermission: Permisos de rutas
CREATE TABLE IF NOT EXISTS pronto_route_permissions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(64) NOT NULL UNIQUE,
    description TEXT,
    display_name VARCHAR(120) NOT NULL,
    app_target VARCHAR(32) NOT NULL
);

-- EmployeeRouteAccess: Acceso a rutas por empleado
CREATE TABLE IF NOT EXISTS pronto_employee_route_access (
    employee_id INTEGER NOT NULL REFERENCES pronto_employees(id),
    route_permission_id INTEGER NOT NULL REFERENCES pronto_route_permissions(id),
    granted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (employee_id, route_permission_id)
);
