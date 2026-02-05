-- Migration: Add avatar field to customers table
-- Date: 2025-01-06
-- Description: Add avatar field to store predefined avatar selection for customers

-- Add avatar column to customers table
ALTER TABLE customers
ADD COLUMN avatar VARCHAR(255) NULL
COMMENT 'Profile avatar filename from predefined set';

-- Update existing anonymous customers to have 'avatar-a.svg' as default
UPDATE customers
SET avatar = 'avatar-a.svg'
WHERE (name_encrypted LIKE '%Cliente%' OR name_encrypted LIKE '%Anónimo%' OR name_encrypted LIKE '%A%')
  AND avatar IS NULL;

-- Optional: Set a random default avatar for other customers
-- UPDATE customers
-- SET avatar = CONCAT('avatar-', FLOOR(1 + RAND() * 5), '.svg')
-- WHERE avatar IS NULL;
