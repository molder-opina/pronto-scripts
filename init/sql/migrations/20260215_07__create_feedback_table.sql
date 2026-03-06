-- Create feedback table for customer ratings
-- Migration: 20260215_07__create_feedback_table.sql

CREATE TABLE IF NOT EXISTS pronto_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES pronto_dining_sessions(id),
    customer_id UUID REFERENCES pronto_customers(id),
    employee_id UUID REFERENCES pronto_employees(id),
    category VARCHAR(50) NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    is_anonymous BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_feedback_session ON pronto_feedback(session_id);
CREATE INDEX IF NOT EXISTS ix_feedback_employee ON pronto_feedback(employee_id);
CREATE INDEX IF NOT EXISTS ix_feedback_category ON pronto_feedback(category);
CREATE INDEX IF NOT EXISTS ix_feedback_rating ON pronto_feedback(rating);
CREATE INDEX IF NOT EXISTS ix_feedback_created_at ON pronto_feedback(created_at);
