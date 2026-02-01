-- Customer: Clientes con campos encriptados
CREATE TABLE IF NOT EXISTS pronto_customers (
    id SERIAL PRIMARY KEY,
    name_encrypted TEXT NOT NULL,
    email_encrypted TEXT,
    phone_encrypted TEXT,
    email_hash VARCHAR(128) UNIQUE,
    contact_hash VARCHAR(128),
    anon_id VARCHAR(64) UNIQUE,
    physical_description TEXT,
    avatar VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_customer_email_hash ON pronto_customers(email_hash);
CREATE INDEX IF NOT EXISTS ix_customer_created_at ON pronto_customers(created_at);
