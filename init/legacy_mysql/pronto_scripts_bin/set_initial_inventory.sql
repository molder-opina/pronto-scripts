-- Migration: Set initial inventory for existing products
-- Date: 2025-11-06
-- Description: Configure initial stock for menu items

-- Enable inventory tracking and set initial stock for specific products
-- Combo Familiar: Limited stock (popular item)
UPDATE menu_items
SET track_inventory = 1,
    stock_quantity = 50,
    low_stock_threshold = 10
WHERE id = 1;

-- Hamburguesa Doble Queso: Limited stock
UPDATE menu_items
SET track_inventory = 1,
    stock_quantity = 100,
    low_stock_threshold = 20
WHERE id = 2;

-- Cheesecake Frutos Rojos: Keep unlimited (no inventory tracking)
-- No changes needed, remains with track_inventory = 0 and stock_quantity = NULL
