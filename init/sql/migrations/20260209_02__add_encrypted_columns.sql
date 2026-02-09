-- Migration to add encrypted columns for Employee table
-- Required for pronto-api ORM compatibility

ALTER TABLE pronto_employees ADD COLUMN IF NOT EXISTS auth_hash VARCHAR(128);
ALTER TABLE pronto_employees ADD COLUMN IF NOT EXISTS email_hash VARCHAR(128);
ALTER TABLE pronto_employees ADD COLUMN IF NOT EXISTS email_encrypted TEXT;
ALTER TABLE pronto_employees ADD COLUMN IF NOT EXISTS name_encrypted TEXT;

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS ix_employee_email_hash ON pronto_employees(email_hash);
-- ix_employee_role_active might already exist or not
CREATE INDEX IF NOT EXISTS ix_employee_role_active ON pronto_employees(role, status); 
-- status matches is_active conceptually, but model uses is_active boolean vs status string?
-- Model: is_active: Mapped[bool]
-- DB: status: varchar(20) ('active')
-- This is another mismatch, but let's focus on Auth first.
