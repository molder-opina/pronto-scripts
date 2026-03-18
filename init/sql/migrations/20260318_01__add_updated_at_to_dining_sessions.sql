-- Add updated_at column to pronto_dining_sessions
-- Reference: PRONTO-PAY-005 Auto-close sessions
ALTER TABLE pronto_dining_sessions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
