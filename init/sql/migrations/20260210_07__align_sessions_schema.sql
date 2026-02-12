-- Align pronto_dining_sessions schema with DiningSession model

-- Rename columns to match model
ALTER TABLE pronto_dining_sessions RENAME COLUMN start_time TO opened_at;
ALTER TABLE pronto_dining_sessions RENAME COLUMN end_time TO closed_at;
ALTER TABLE pronto_dining_sessions RENAME COLUMN total TO total_amount;

-- Add missing columns
ALTER TABLE pronto_dining_sessions ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE pronto_dining_sessions ADD COLUMN IF NOT EXISTS payment_reference VARCHAR(128);
ALTER TABLE pronto_dining_sessions ADD COLUMN IF NOT EXISTS payment_confirmed_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE pronto_dining_sessions ADD COLUMN IF NOT EXISTS tip_requested_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE pronto_dining_sessions ADD COLUMN IF NOT EXISTS tip_confirmed_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE pronto_dining_sessions ADD COLUMN IF NOT EXISTS check_requested_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE pronto_dining_sessions ADD COLUMN IF NOT EXISTS feedback_requested_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE pronto_dining_sessions ADD COLUMN IF NOT EXISTS feedback_completed_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE pronto_dining_sessions ADD COLUMN IF NOT EXISTS email_encrypted TEXT;
ALTER TABLE pronto_dining_sessions ADD COLUMN IF NOT EXISTS email_hash VARCHAR(128);

-- Add indexes for new columns if needed (optional but good practice)
CREATE INDEX IF NOT EXISTS ix_session_email_hash ON pronto_dining_sessions(email_hash);
