-- Migration: Unify Permissions Schema
-- Date: 2026-02-16
-- Description: Drop legacy permission tables replaced by pronto_system_roles and pronto_role_permission_bindings

BEGIN;

-- 1. Eliminar tablas del Sistema 1 (Route Permissions)
DROP TABLE IF EXISTS pronto_employee_route_access CASCADE;
DROP TABLE IF EXISTS pronto_route_permissions CASCADE;

-- 2. Eliminar tablas del Sistema 3 (Custom Roles Legacy)
-- Antes de borrar, podríamos migrar datos si hubiera, pero se confirmó count=0 en pronto_custom_roles
DROP TABLE IF EXISTS pronto_role_permissions CASCADE;
DROP TABLE IF EXISTS pronto_custom_roles CASCADE;

COMMIT;
