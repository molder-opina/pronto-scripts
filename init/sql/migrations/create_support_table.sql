-- Creates the support_tickets table.
-- Run inside the MySQL database used by the app (see README/docker-compose for env vars).

CREATE TABLE IF NOT EXISTS support_tickets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    channel VARCHAR(32) NOT NULL DEFAULT 'client',
    name_encrypted TEXT NOT NULL,
    email_encrypted TEXT NOT NULL,
    description_encrypted TEXT NOT NULL,
    page_url VARCHAR(255),
    user_agent VARCHAR(255),
    status VARCHAR(32) NOT NULL DEFAULT 'open',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at DATETIME NULL,
    INDEX ix_support_ticket_status (status),
    INDEX ix_support_ticket_created_at (created_at),
    INDEX ix_support_ticket_channel (channel)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
