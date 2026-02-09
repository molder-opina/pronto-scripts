-- Migration to add is_active column to pronto_employees
-- Required by ORM model

ALTER TABLE pronto_employees ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
UPDATE pronto_employees SET is_active = (status = 'active');
ALTER TABLE pronto_employees ALTER COLUMN is_active SET NOT NULL;
