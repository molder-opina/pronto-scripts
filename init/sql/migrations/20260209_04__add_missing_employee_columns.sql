-- Migration to add missing columns to pronto_employees
-- Required by ORM model

ALTER TABLE pronto_employees ADD COLUMN IF NOT EXISTS allow_scopes JSONB;
ALTER TABLE pronto_employees ADD COLUMN IF NOT EXISTS additional_roles TEXT;
