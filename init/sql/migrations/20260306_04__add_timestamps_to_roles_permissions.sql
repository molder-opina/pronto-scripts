-- Migration: 20260306_04__add_timestamps_to_roles_permissions.sql
-- Date: 2026-03-06
-- Description: Adds missing created_at and updated_at columns to pronto_system_roles and pronto_system_permissions

BEGIN;

-- 1. Add missing updated_at to pronto_system_roles
ALTER TABLE public.pronto_system_roles
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now();

-- 2. Add missing created_at and updated_at to pronto_system_permissions
ALTER TABLE public.pronto_system_permissions
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now();

COMMIT;
