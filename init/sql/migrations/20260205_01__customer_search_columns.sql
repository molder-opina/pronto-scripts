-- Customer search columns for fast lookup
-- Run: ./pronto-scripts/bin/pronto-migrate --apply

ALTER TABLE pronto_customers ADD COLUMN IF NOT EXISTS name_search TEXT;
ALTER TABLE pronto_customers ADD COLUMN IF NOT EXISTS email_normalized TEXT;
ALTER TABLE pronto_customers ADD COLUMN IF NOT EXISTS phone_e164 TEXT;

CREATE INDEX IF NOT EXISTS ix_customer_name_search ON pronto_customers(name_search);
CREATE INDEX IF NOT EXISTS ix_customer_email_normalized ON pronto_customers(email_normalized);
CREATE INDEX IF NOT EXISTS ix_customer_phone_e164 ON pronto_customers(phone_e164);
