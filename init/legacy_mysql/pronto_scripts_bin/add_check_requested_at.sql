-- Add check_requested_at field to dining_sessions table
-- This tracks when a customer requested their check/bill

ALTER TABLE dining_sessions
ADD COLUMN check_requested_at DATETIME NULL
COMMENT 'Timestamp when customer requested check/bill';

-- Add index for efficient querying of sessions awaiting payment
CREATE INDEX ix_dining_session_check_requested
ON dining_sessions(check_requested_at);
