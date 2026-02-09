-- Migration to add activity timestamps to pronto_employees
-- Required by ORM model

ALTER TABLE pronto_employees ADD COLUMN IF NOT EXISTS signed_in_at TIMESTAMP;
ALTER TABLE pronto_employees ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMP;
