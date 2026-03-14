-- Creates the support_tickets table on PostgreSQL.

CREATE TABLE IF NOT EXISTS support_tickets (
    id BIGSERIAL PRIMARY KEY,
    channel VARCHAR(32) NOT NULL DEFAULT 'client',
    name_encrypted TEXT NOT NULL,
    email_encrypted TEXT NOT NULL,
    description_encrypted TEXT NOT NULL,
    page_url VARCHAR(255),
    user_agent VARCHAR(255),
    status VARCHAR(32) NOT NULL DEFAULT 'open',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL
);

CREATE INDEX IF NOT EXISTS ix_support_ticket_status ON support_tickets(status);
CREATE INDEX IF NOT EXISTS ix_support_ticket_created_at ON support_tickets(created_at);
CREATE INDEX IF NOT EXISTS ix_support_ticket_channel ON support_tickets(channel);
