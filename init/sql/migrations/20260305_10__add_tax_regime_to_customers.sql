-- Migration: Add tax_regime column to pronto_customers
-- Date: 2026-03-05

ALTER TABLE pronto_customers ADD COLUMN IF NOT EXISTS tax_regime VARCHAR(3);
