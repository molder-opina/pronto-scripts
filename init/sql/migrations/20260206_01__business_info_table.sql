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

-- Insert default business info if not exists
INSERT INTO pronto_business_info (restaurant_slug, restaurant_name)
SELECT 'default', 'PRONTO Restaurant'
WHERE NOT EXISTS (SELECT 1 FROM pronto_business_info WHERE restaurant_slug = 'default');

COMMENT ON TABLE pronto_business_info IS 'Restaurant business configuration and branding settings';
COMMENT ON COLUMN pronto_business_info.restaurant_slug IS 'URL-friendly identifier for the restaurant';
