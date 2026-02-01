-- Notification: Notificaciones
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
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    read_at TIMESTAMP,
    dismissed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_notification_recipient_type_status ON pronto_notifications(recipient_type, recipient_id, status);
CREATE INDEX IF NOT EXISTS ix_notification_created_at ON pronto_notifications(created_at);
CREATE INDEX IF NOT EXISTS ix_notification_type ON pronto_notifications(notification_type);
