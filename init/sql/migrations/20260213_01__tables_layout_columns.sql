-- Ensure table-layout columns exist for visual table management.
-- This aligns DB schema with SQLAlchemy model/TableService expectations.

ALTER TABLE pronto_tables
  ADD COLUMN IF NOT EXISTS position_x INTEGER;

ALTER TABLE pronto_tables
  ADD COLUMN IF NOT EXISTS position_y INTEGER;

ALTER TABLE pronto_tables
  ADD COLUMN IF NOT EXISTS shape VARCHAR(32) DEFAULT 'square';

ALTER TABLE pronto_tables
  ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE pronto_tables
  ALTER COLUMN status SET DEFAULT 'available';
