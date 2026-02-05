-- Add targeting fields to promotions and discount_codes tables
-- This allows targeting by tags, specific products, or packages instead of just "all"

-- Add fields to promotions table
ALTER TABLE promotions
ADD COLUMN applicable_tags TEXT NULL COMMENT 'JSON array of tags for tag-based targeting',
ADD COLUMN applicable_products TEXT NULL COMMENT 'JSON array of product IDs for product-specific targeting';

-- Update existing promotions to have products applies_to instead of all
UPDATE promotions
SET applies_to = 'products'
WHERE applies_to = 'all';

-- Add fields to discount_codes table
ALTER TABLE discount_codes
ADD COLUMN applicable_tags TEXT NULL COMMENT 'JSON array of tags for tag-based targeting',
ADD COLUMN applicable_products TEXT NULL COMMENT 'JSON array of product IDs for product-specific targeting';

-- Update existing discount codes to have products applies_to instead of all
UPDATE discount_codes
SET applies_to = 'products'
WHERE applies_to = 'all';
