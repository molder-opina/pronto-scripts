-- Apply all pending migrations in order
-- Database: pronto
-- Date: 2025-11-11

-- =====================================================================
-- Migration 001: Add employee sign-in and activity tracking
-- =====================================================================

-- Add new columns to employees table
ALTER TABLE employees
ADD COLUMN signed_in_at DATETIME NULL AFTER created_at,
ADD COLUMN last_activity_at DATETIME NULL AFTER signed_in_at;

-- Add index for efficient querying of active employees
-- Note: MySQL doesn't support filtered indexes like PostgreSQL
CREATE INDEX ix_employee_last_activity ON employees(last_activity_at);

-- =====================================================================
-- Migration 004: Add additional_roles field to employees table
-- =====================================================================

-- Add additional_roles column to store JSON array of extra roles
ALTER TABLE employees
ADD COLUMN additional_roles TEXT NULL
COMMENT 'JSON array of additional roles beyond primary role'
AFTER role;

-- Create index for better query performance
CREATE INDEX idx_employees_additional_roles ON employees(additional_roles(255));

-- Set default additional_roles for existing waiters (make them also cashiers by default)
UPDATE employees
SET additional_roles = '["cashier"]'
WHERE role = 'waiter' AND (additional_roles IS NULL OR additional_roles = '');

-- Commit all changes
COMMIT;
