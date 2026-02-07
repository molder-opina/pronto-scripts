-- Migration: Create pronto_business_info table
-- Created: 2026-02-06
-- Purpose: Core business information singleton table

CREATE TABLE IF NOT EXISTS pronto_business_info (
    id INTEGER PRIMARY KEY,
    business_name VARCHAR(200) NOT NULL,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    phone VARCHAR(50),
    email VARCHAR(200),
    website VARCHAR(200),
    logo_url VARCHAR(500),
    description TEXT,
    currency VARCHAR(10) NOT NULL DEFAULT 'MXN',
    timezone VARCHAR(50) NOT NULL DEFAULT 'America/Mexico_City',
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_by INTEGER REFERENCES pronto_employees(id)
);

-- Insert default business info (singleton)
INSERT INTO pronto_business_info (
    id, business_name, address, city, state, postal_code,
    country, phone, email, website, description, currency, timezone
) VALUES (
    1,
    'Cafetería de Prueba',
    'Av. Principal 123',
    'Ciudad de México',
    'CDMX',
    '01000',
    'México',
    '+52 55 1234 5678',
    'info@cafeteria-prueba.com',
    'https://cafeteria-prueba.com',
    'Cafetería de Prueba - Sistema PRONTO',
    'MXN',
    'America/Mexico_City'
) ON CONFLICT (id) DO NOTHING;
