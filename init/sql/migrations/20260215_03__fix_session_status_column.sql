-- Migration: 20260215_03__fix_session_status_column.sql
-- Fix: Increase dining_sessions.status column from varchar(20) to varchar(50)
-- Reason: New status values like 'awaiting_payment_confirmation' exceed 20 chars

ALTER TABLE pronto_dining_sessions 
ALTER COLUMN status TYPE VARCHAR(50);

-- Also ensure status column has room for future statuses
COMMENT ON COLUMN pronto_dining_sessions.status IS 'Session status: open, active, awaiting_tip, awaiting_payment, awaiting_payment_confirmation, closed, paid';
