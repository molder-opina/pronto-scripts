-- Add encrypted columns to pronto_customers table
ALTER TABLE pronto_customers ADD COLUMN IF NOT EXISTS email_encrypted TEXT;
ALTER TABLE pronto_customers ADD COLUMN IF NOT EXISTS name_encrypted TEXT;
ALTER TABLE pronto_customers ADD COLUMN IF NOT EXISTS phone_encrypted TEXT;
ALTER TABLE pronto_customers ADD COLUMN IF NOT EXISTS auth_hash VARCHAR(128);
ALTER TABLE pronto_customers ADD COLUMN IF NOT EXISTS email_hash VARCHAR(128);

CREATE INDEX IF NOT EXISTS ix_customer_email_hash ON pronto_customers(email_hash);
