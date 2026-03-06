-- Migration to add preferences column to pronto_employees
-- Required by ORM model

ALTER TABLE pronto_employees ADD COLUMN IF NOT EXISTS preferences JSONB;
