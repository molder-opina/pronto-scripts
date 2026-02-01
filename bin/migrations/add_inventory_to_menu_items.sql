-- Migration: Add inventory tracking columns to menu_items table
-- Date: 2025-11-06
-- Description: Add optional inventory tracking system for menu items

-- Add inventory tracking columns
ALTER TABLE menu_items
ADD COLUMN track_inventory TINYINT(1) NOT NULL DEFAULT 0
COMMENT 'Enable inventory tracking for this product';

ALTER TABLE menu_items
ADD COLUMN stock_quantity INT NULL DEFAULT NULL
COMMENT 'Current stock quantity (NULL = unlimited)';

ALTER TABLE menu_items
ADD COLUMN low_stock_threshold INT NULL DEFAULT 10
COMMENT 'Alert threshold for low stock notifications';

-- Create index for inventory queries
CREATE INDEX idx_menu_items_inventory ON menu_items(track_inventory, stock_quantity);

-- Add comment to table
ALTER TABLE menu_items COMMENT = 'Menu items with optional inventory tracking';
