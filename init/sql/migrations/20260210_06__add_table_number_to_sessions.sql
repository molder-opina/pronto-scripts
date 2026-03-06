-- Add table_number to pronto_dining_sessions (deprecated but required by ORM)
ALTER TABLE pronto_dining_sessions ADD COLUMN IF NOT EXISTS table_number VARCHAR(32);
