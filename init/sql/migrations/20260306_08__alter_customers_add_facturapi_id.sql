-- Add facturapi_customer_id to customers table
-- This stores the Facturapi customer ID for electronic invoicing

ALTER TABLE pronto_customers
ADD COLUMN IF NOT EXISTS facturapi_customer_id VARCHAR(64);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_customers_facturapi_id
ON pronto_customers(facturapi_customer_id);
