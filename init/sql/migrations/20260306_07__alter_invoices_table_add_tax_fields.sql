-- Migration: Add missing columns to pronto_invoices table
-- Date: 2026-03-06
-- Description: Add tax fields and other missing columns for CFDI 4.0 compliance

-- Add tax information columns
ALTER TABLE pronto_invoices ADD COLUMN IF NOT EXISTS tax_id VARCHAR(13);
ALTER TABLE pronto_invoices ADD COLUMN IF NOT EXISTS tax_name VARCHAR(255);
ALTER TABLE pronto_invoices ADD COLUMN IF NOT EXISTS tax_system VARCHAR(3);

-- Add facturapi customer reference
ALTER TABLE pronto_invoices ADD COLUMN IF NOT EXISTS facturapi_customer_id VARCHAR(64);

-- Add cancellation tracking
ALTER TABLE pronto_invoices ADD COLUMN IF NOT EXISTS cancelled_by UUID REFERENCES pronto_employees(id) ON DELETE SET NULL;

-- Add notes and raw response
ALTER TABLE pronto_invoices ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE pronto_invoices ADD COLUMN IF NOT EXISTS raw_response JSONB;

-- Add discount column
ALTER TABLE pronto_invoices ADD COLUMN IF NOT EXISTS discount NUMERIC(12, 2) DEFAULT 0;

-- Add series column (rename if needed, or add new)
ALTER TABLE pronto_invoices ADD COLUMN IF NOT EXISTS series VARCHAR(5);

-- Make customer_id nullable (invoices can be for walk-in customers)
ALTER TABLE pronto_invoices ALTER COLUMN customer_id DROP NOT NULL;

-- Comments
COMMENT ON COLUMN pronto_invoices.tax_id IS 'RFC of the customer receiving the invoice';
COMMENT ON COLUMN pronto_invoices.tax_name IS 'Legal name of the customer for invoicing';
COMMENT ON COLUMN pronto_invoices.tax_system IS 'SAT tax regime code (e.g., 601, 612, 621)';
COMMENT ON COLUMN pronto_invoices.facturapi_customer_id IS 'Facturapi customer ID for quick lookups';
COMMENT ON COLUMN pronto_invoices.cancelled_by IS 'Employee who cancelled the invoice';
COMMENT ON COLUMN pronto_invoices.notes IS 'Internal notes about the invoice';
COMMENT ON COLUMN pronto_invoices.raw_response IS 'Full Facturapi response for debugging';

-- Add index for facturapi_customer_id
CREATE INDEX IF NOT EXISTS ix_invoices_facturapi_customer_id ON pronto_invoices(facturapi_customer_id);
