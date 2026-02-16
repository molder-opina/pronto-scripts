-- Add feedback_rating and feedback_comment columns to dining_sessions
-- Migration: 20260215_06__add_feedback_columns.sql

ALTER TABLE pronto_dining_sessions 
ADD COLUMN IF NOT EXISTS feedback_rating INTEGER,
ADD COLUMN IF NOT EXISTS feedback_comment TEXT;

CREATE INDEX IF NOT EXISTS ix_dining_session_feedback_rating 
ON pronto_dining_sessions(feedback_rating) 
WHERE feedback_rating IS NOT NULL;
