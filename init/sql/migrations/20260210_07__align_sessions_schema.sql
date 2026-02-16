-- Align pronto_dining_sessions schema with DiningSession model

-- Rename legacy columns only when present and target does not already exist.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pronto_dining_sessions' AND column_name = 'start_time'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pronto_dining_sessions' AND column_name = 'opened_at'
  ) THEN
    EXECUTE 'ALTER TABLE pronto_dining_sessions RENAME COLUMN start_time TO opened_at';
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pronto_dining_sessions' AND column_name = 'end_time'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pronto_dining_sessions' AND column_name = 'closed_at'
  ) THEN
    EXECUTE 'ALTER TABLE pronto_dining_sessions RENAME COLUMN end_time TO closed_at';
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pronto_dining_sessions' AND column_name = 'total'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'pronto_dining_sessions' AND column_name = 'total_amount'
  ) THEN
    EXECUTE 'ALTER TABLE pronto_dining_sessions RENAME COLUMN total TO total_amount';
  END IF;
END $$;

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
