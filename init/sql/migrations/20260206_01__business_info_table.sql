-- Migration: 20260206_01__business_info_table.sql
-- Purpose: Create business_info table for restaurant configuration

CREATE TABLE IF NOT EXISTS pronto_business_info (
    id SERIAL PRIMARY KEY,
    restaurant_name VARCHAR(255) NOT NULL DEFAULT 'PRONTO',
    restaurant_slug VARCHAR(100) UNIQUE NOT NULL,
    currency_symbol VARCHAR(10) DEFAULT '$',
    currency_code VARCHAR(10) DEFAULT 'MXN',
    timezone VARCHAR(50) DEFAULT 'America/Mexico_City',
    logo_path VARCHAR(500),
    favicon_path VARCHAR(500),
    primary_color VARCHAR(7) DEFAULT '#FF6B35',
    secondary_color VARCHAR(7) DEFAULT '#2D3142',
    accent_color VARCHAR(7) DEFAULT '#4ECDC4',
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(255),
    website_url VARCHAR(500),
    tax_rate DECIMAL(5,2) DEFAULT 16.00,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for fast lookups
CREATE INDEX IF NOT EXISTS idx_business_info_slug ON pronto_business_info(restaurant_slug);
CREATE INDEX IF NOT EXISTS idx_business_info_active ON pronto_business_info(is_active);

-- Repair legacy/live instances where the table exists but `id` lost its serial default.
DO $$
DECLARE
    max_id integer;
BEGIN
    CREATE SEQUENCE IF NOT EXISTS pronto_business_info_id_seq;

    ALTER SEQUENCE pronto_business_info_id_seq OWNED BY pronto_business_info.id;
    ALTER TABLE pronto_business_info
        ALTER COLUMN id SET DEFAULT nextval('pronto_business_info_id_seq');

    SELECT COALESCE(MAX(id), 0) INTO max_id FROM pronto_business_info;

    IF max_id > 0 THEN
        PERFORM setval('pronto_business_info_id_seq', max_id, true);
    ELSE
        PERFORM setval('pronto_business_info_id_seq', 1, false);
    END IF;
END $$;

-- Insert default business info if not exists, tolerating legacy live schemas that still require
-- `business_name` before later alignment migrations run.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'pronto_business_info'
          AND column_name = 'business_name'
    ) THEN
        INSERT INTO pronto_business_info (restaurant_slug, restaurant_name, business_name)
        SELECT 'default', 'PRONTO Restaurant', 'PRONTO Restaurant'
        WHERE NOT EXISTS (
            SELECT 1 FROM pronto_business_info WHERE restaurant_slug = 'default'
        );
    ELSE
        INSERT INTO pronto_business_info (restaurant_slug, restaurant_name)
        SELECT 'default', 'PRONTO Restaurant'
        WHERE NOT EXISTS (
            SELECT 1 FROM pronto_business_info WHERE restaurant_slug = 'default'
        );
    END IF;
END $$;

COMMENT ON TABLE pronto_business_info IS 'Restaurant business configuration and branding settings';
COMMENT ON COLUMN pronto_business_info.restaurant_slug IS 'URL-friendly identifier for the restaurant';
