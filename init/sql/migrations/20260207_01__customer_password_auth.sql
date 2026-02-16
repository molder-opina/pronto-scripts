ALTER TABLE pronto_customers ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);
ALTER TABLE pronto_customers ADD COLUMN IF NOT EXISTS email_hash VARCHAR(128);

CREATE INDEX IF NOT EXISTS ix_customer_email_hash ON pronto_customers(email_hash);
