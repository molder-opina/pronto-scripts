-- Indexes for PRONTO tables
-- Additional indexes beyond those defined inline in 10_schema

-- Order performance indexes
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON pronto_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_chef_id ON pronto_orders(chef_id) WHERE chef_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON pronto_orders(created_at DESC);

-- Session indexes
CREATE INDEX IF NOT EXISTS idx_sessions_table_id ON pronto_dining_sessions(table_id) WHERE table_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_sessions_customer_id ON pronto_dining_sessions(customer_id) WHERE customer_id IS NOT NULL;

-- Employee indexes  
CREATE INDEX IF NOT EXISTS idx_employees_role_status ON pronto_employees(role, status);

-- Menu item search
CREATE INDEX IF NOT EXISTS idx_menu_items_name ON pronto_menu_items(name);
CREATE INDEX IF NOT EXISTS idx_menu_items_category ON pronto_menu_items(category_id);
