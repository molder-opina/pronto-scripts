-- Migration: Add password reset columns to customers and employees
-- Date: 2026-03-05

BEGIN;

-- Add columns to pronto_customers
ALTER TABLE pronto_customers ADD COLUMN IF NOT EXISTS reset_token VARCHAR(100);
ALTER TABLE pronto_customers ADD COLUMN IF NOT EXISTS reset_token_expires_at TIMESTAMP WITHOUT TIME ZONE;

-- Add columns to pronto_employees
ALTER TABLE pronto_employees ADD COLUMN IF NOT EXISTS reset_token VARCHAR(100);
ALTER TABLE pronto_employees ADD COLUMN IF NOT EXISTS reset_token_expires_at TIMESTAMP WITHOUT TIME ZONE;

COMMIT;
