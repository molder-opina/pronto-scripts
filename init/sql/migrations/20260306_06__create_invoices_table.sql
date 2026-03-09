-- Migration: Create pronto_invoices table for CFDI 4.0 electronic invoicing
-- Date: 2026-03-06
-- Description: Stores invoice metadata generated via Facturapi

CREATE TABLE IF NOT EXISTS pronto_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Facturapi references
    facturapi_id VARCHAR(64),
    facturapi_customer_id VARCHAR(64),
    cfdi_uuid VARCHAR(36),  -- SAT UUID

    -- Local references
    customer_id UUID REFERENCES pronto_customers(id) ON DELETE SET NULL,
    dining_session_id UUID REFERENCES pronto_dining_sessions(id) ON DELETE SET NULL,
    order_id UUID REFERENCES pronto_orders(id) ON DELETE SET NULL,

    -- Invoice details
    folio VARCHAR(20),
    series VARCHAR(5),

    -- Tax information
    tax_id VARCHAR(13),  -- RFC
    tax_name VARCHAR(255),
    tax_system VARCHAR(3),  -- SAT regime code
    use_cfdi VARCHAR(4) DEFAULT 'G03',
    payment_form VARCHAR(2) DEFAULT '03',
    payment_method VARCHAR(3) DEFAULT 'PUE',

    -- Amounts
    subtotal NUMERIC(12, 2) NOT NULL,
    tax NUMERIC(12, 2) DEFAULT 0,
    total NUMERIC(12, 2) NOT NULL,
    discount NUMERIC(12, 2) DEFAULT 0,

    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'pending',  -- pending, issued, cancelled, error

    -- URLs (from Facturapi)
    pdf_url VARCHAR(500),
    xml_url VARCHAR(500),

    -- Error handling
    error_message TEXT,

    -- Cancellation
    cancelled_at TIMESTAMP,
    cancelled_by UUID REFERENCES pronto_employees(id) ON DELETE SET NULL,
    cancellation_motive VARCHAR(2),  -- 01, 02, 03, 04
    cancellation_substitution_uuid VARCHAR(36),

    -- Metadata
    notes TEXT,
    raw_response JSONB,

    -- Timestamps
    issued_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Indices for common queries
CREATE INDEX IF NOT EXISTS ix_invoices_customer_id ON pronto_invoices(customer_id);
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'pronto_invoices'
          AND column_name = 'dining_session_id'
    ) THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_invoices_dining_session_id ON pronto_invoices(dining_session_id)';
    ELSIF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'pronto_invoices'
          AND column_name = 'session_id'
    ) THEN
        EXECUTE 'CREATE INDEX IF NOT EXISTS ix_invoices_session_id ON pronto_invoices(session_id)';
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS ix_invoices_status ON pronto_invoices(status);
CREATE INDEX IF NOT EXISTS ix_invoices_created_at ON pronto_invoices(created_at);
CREATE INDEX IF NOT EXISTS ix_invoices_facturapi_id ON pronto_invoices(facturapi_id);
CREATE INDEX IF NOT EXISTS ix_invoices_cfdi_uuid ON pronto_invoices(cfdi_uuid);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_invoices_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'trigger_invoices_updated_at'
          AND tgrelid = 'pronto_invoices'::regclass
          AND NOT tgisinternal
    ) THEN
        CREATE TRIGGER trigger_invoices_updated_at
            BEFORE UPDATE ON pronto_invoices
            FOR EACH ROW
            EXECUTE FUNCTION update_invoices_updated_at();
    END IF;
END $$;

-- Comment on table
COMMENT ON TABLE pronto_invoices IS 'Electronic invoices (CFDI 4.0) generated via Facturapi';
COMMENT ON COLUMN pronto_invoices.cfdi_uuid IS 'SAT UUID (Folio Fiscal) assigned to the invoice';
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'pronto_invoices'
          AND column_name = 'tax_id'
    ) THEN
        COMMENT ON COLUMN pronto_invoices.tax_id IS 'RFC of the customer receiving the invoice';
    END IF;
END $$;
COMMENT ON COLUMN pronto_invoices.use_cfdi IS 'CFDI use code from SAT catalog';
COMMENT ON COLUMN pronto_invoices.payment_form IS 'Payment form code from SAT catalog (01-31, 99)';
COMMENT ON COLUMN pronto_invoices.payment_method IS 'Payment method: PUE (single payment) or PPD (deferred)';
