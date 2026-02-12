-- Add total_paid column to pronto_dining_sessions table
ALTER TABLE pronto_dining_sessions ADD COLUMN IF NOT EXISTS total_paid NUMERIC(12, 2) DEFAULT 0.00;
