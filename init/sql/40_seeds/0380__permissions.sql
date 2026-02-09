-- ============================================================================
-- PRONTO SEED: System Permissions
-- ============================================================================
-- Creates basic system permissions and role bindings
-- Run order: 0380 (after employees)
-- ============================================================================

-- System Roles
INSERT INTO pronto_system_roles (id, name, description, is_system_role, created_at)
VALUES
    (gen_random_uuid(), 'system', 'Super administrator with full access', true, NOW()),
    (gen_random_uuid(), 'admin', 'Administrator with management access', true, NOW()),
    (gen_random_uuid(), 'waiter', 'Waiter with order and table management', true, NOW()),
    (gen_random_uuid(), 'chef', 'Chef with kitchen display access', true, NOW()),
    (gen_random_uuid(), 'cashier', 'Cashier with payment processing', true, NOW())
ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    is_system_role = EXCLUDED.is_system_role;

-- System Permissions
INSERT INTO pronto_system_permissions (id, name, description, resource, action, created_at)
VALUES
    -- Order permissions
    (gen_random_uuid(), 'order:create', 'Create new orders', 'order', 'create', NOW()),
    (gen_random_uuid(), 'order:read', 'View orders', 'order', 'read', NOW()),
    (gen_random_uuid(), 'order:update', 'Update orders', 'order', 'update', NOW()),
    (gen_random_uuid(), 'order:delete', 'Cancel orders', 'order', 'delete', NOW()),
    (gen_random_uuid(), 'order:accept', 'Accept orders', 'order', 'accept', NOW()),
    (gen_random_uuid(), 'order:complete', 'Complete orders', 'order', 'complete', NOW()),
    
    -- Menu permissions
    (gen_random_uuid(), 'menu:read', 'View menu', 'menu', 'read', NOW()),
    (gen_random_uuid(), 'menu:manage', 'Manage menu items', 'menu', 'manage', NOW()),
    
    -- Table permissions
    (gen_random_uuid(), 'table:read', 'View tables', 'table', 'read', NOW()),
    (gen_random_uuid(), 'table:manage', 'Manage tables', 'table', 'manage', NOW()),
    
    -- Payment permissions
    (gen_random_uuid(), 'payment:process', 'Process payments', 'payment', 'process', NOW()),
    (gen_random_uuid(), 'payment:refund', 'Refund payments', 'payment', 'refund', NOW()),
    
    -- Employee permissions
    (gen_random_uuid(), 'employee:read', 'View employees', 'employee', 'read', NOW()),
    (gen_random_uuid(), 'employee:manage', 'Manage employees', 'employee', 'manage', NOW()),
    
    -- Analytics permissions
    (gen_random_uuid(), 'analytics:view', 'View analytics', 'analytics', 'view', NOW()),
    
    -- Settings permissions
    (gen_random_uuid(), 'settings:read', 'View settings', 'settings', 'read', NOW()),
    (gen_random_uuid(), 'settings:manage', 'Manage settings', 'settings', 'manage', NOW())
ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    resource = EXCLUDED.resource,
    action = EXCLUDED.action;

-- Role Permission Bindings
-- System role: all permissions
INSERT INTO pronto_role_permission_bindings (role_id, permission_id)
SELECT 
    (SELECT id FROM pronto_system_roles WHERE name = 'system'),
    id
FROM pronto_system_permissions
ON CONFLICT DO NOTHING;

-- Admin role: most permissions except system-level
INSERT INTO pronto_role_permission_bindings (role_id, permission_id)
SELECT 
    (SELECT id FROM pronto_system_roles WHERE name = 'admin'),
    id
FROM pronto_system_permissions
WHERE name NOT LIKE 'settings:manage'
ON CONFLICT DO NOTHING;

-- Waiter role: order and table management
INSERT INTO pronto_role_permission_bindings (role_id, permission_id)
SELECT 
    (SELECT id FROM pronto_system_roles WHERE name = 'waiter'),
    id
FROM pronto_system_permissions
WHERE name IN (
    'order:create', 'order:read', 'order:update', 'order:accept',
    'menu:read', 'table:read', 'table:manage'
)
ON CONFLICT DO NOTHING;

-- Chef role: order viewing and completion
INSERT INTO pronto_role_permission_bindings (role_id, permission_id)
SELECT 
    (SELECT id FROM pronto_system_roles WHERE name = 'chef'),
    id
FROM pronto_system_permissions
WHERE name IN (
    'order:read', 'order:complete', 'menu:read'
)
ON CONFLICT DO NOTHING;

-- Cashier role: payment processing
INSERT INTO pronto_role_permission_bindings (role_id, permission_id)
SELECT 
    (SELECT id FROM pronto_system_roles WHERE name = 'cashier'),
    id
FROM pronto_system_permissions
WHERE name IN (
    'order:read', 'payment:process', 'payment:refund',
    'menu:read', 'table:read'
)
ON CONFLICT DO NOTHING;
