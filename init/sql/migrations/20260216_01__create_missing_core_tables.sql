-- Migration: Create missing core tables
-- Date: 2026-02-16
-- Description: Creates pronto_notifications, pronto_waiter_calls, and pronto_realtime_events

BEGIN;

-- 1. Create pronto_notifications
CREATE TABLE IF NOT EXISTS pronto_notifications (
    id SERIAL PRIMARY KEY,
    notification_type VARCHAR(64) NOT NULL,
    recipient_type VARCHAR(32) NOT NULL,
    recipient_id INTEGER,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    data JSONB,
    status VARCHAR(32) NOT NULL DEFAULT 'unread',
    priority VARCHAR(32) NOT NULL DEFAULT 'normal',
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    read_at TIMESTAMP WITHOUT TIME ZONE,
    dismissed_at TIMESTAMP WITHOUT TIME ZONE
);

CREATE INDEX IF NOT EXISTS ix_notification_recipient_type_status ON pronto_notifications (recipient_type, recipient_id, status);
CREATE INDEX IF NOT EXISTS ix_notification_created_at ON pronto_notifications (created_at);
CREATE INDEX IF NOT EXISTS ix_notification_type ON pronto_notifications (notification_type);

-- 2. Create pronto_waiter_calls
CREATE TABLE IF NOT EXISTS pronto_waiter_calls (
    id SERIAL PRIMARY KEY,
    session_id UUID REFERENCES pronto_dining_sessions(id),
    table_number VARCHAR(32),
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    confirmed_at TIMESTAMP WITHOUT TIME ZONE,
    confirmed_by UUID REFERENCES pronto_employees(id),
    cancelled_at TIMESTAMP WITHOUT TIME ZONE,
    notes TEXT
);

CREATE INDEX IF NOT EXISTS ix_waiter_call_session ON pronto_waiter_calls (session_id);
CREATE INDEX IF NOT EXISTS ix_waiter_call_status ON pronto_waiter_calls (status);
CREATE INDEX IF NOT EXISTS ix_waiter_call_created_at ON pronto_waiter_calls (created_at);
CREATE INDEX IF NOT EXISTS ix_waiter_call_confirmed_by ON pronto_waiter_calls (confirmed_by);

-- 3. Create pronto_realtime_events
CREATE TABLE IF NOT EXISTS pronto_realtime_events (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    payload TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_realtime_event_type ON pronto_realtime_events (event_type);
CREATE INDEX IF NOT EXISTS ix_realtime_event_created_at ON pronto_realtime_events (created_at);

COMMIT;
