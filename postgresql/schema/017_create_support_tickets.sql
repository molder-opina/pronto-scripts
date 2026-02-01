-- SupportTicket: Tickets de soporte
CREATE TABLE IF NOT EXISTS pronto_support_tickets (
    id SERIAL PRIMARY KEY,
    channel VARCHAR(32) DEFAULT 'client' NOT NULL,
    name_encrypted TEXT NOT NULL,
    email_encrypted TEXT NOT NULL,
    description_encrypted TEXT NOT NULL,
    page_url VARCHAR(255),
    user_agent VARCHAR(255),
    status VARCHAR(32) DEFAULT 'open' NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_support_ticket_status ON pronto_support_tickets(status);
CREATE INDEX IF NOT EXISTS ix_support_ticket_created_at ON pronto_support_tickets(created_at);
CREATE INDEX IF NOT EXISTS ix_support_ticket_channel ON pronto_support_tickets(channel);
