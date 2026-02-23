-- Add missing indices for foreign keys

CREATE INDEX IF NOT EXISTS idx_pronto_business_info_updated_by ON pronto_business_info (updated_by);
CREATE INDEX IF NOT EXISTS idx_pronto_dining_sessions_customer_id ON pronto_dining_sessions (customer_id);
CREATE INDEX IF NOT EXISTS idx_pronto_dining_sessions_employee_id ON pronto_dining_sessions (employee_id);
CREATE INDEX IF NOT EXISTS idx_pronto_feedback_customer_id ON pronto_feedback (customer_id);
CREATE INDEX IF NOT EXISTS idx_pronto_kitchen_orders_order_id ON pronto_kitchen_orders (order_id);
CREATE INDEX IF NOT EXISTS idx_pronto_menu_categories_parent_category_id ON pronto_menu_categories (parent_category_id);
CREATE INDEX IF NOT EXISTS idx_pronto_modifier_groups_menu_item_id ON pronto_modifier_groups (menu_item_id);
CREATE INDEX IF NOT EXISTS idx_pronto_modifiers_group_id ON pronto_modifiers (group_id);
CREATE INDEX IF NOT EXISTS idx_pronto_order_items_delivered_by_employee_id ON pronto_order_items (delivered_by_employee_id);
CREATE INDEX IF NOT EXISTS idx_pronto_order_items_menu_item_id ON pronto_order_items (menu_item_id);
CREATE INDEX IF NOT EXISTS idx_pronto_order_status_history_changed_by ON pronto_order_status_history (changed_by);
CREATE INDEX IF NOT EXISTS idx_pronto_order_status_labels_updated_by_emp_id ON pronto_order_status_labels (updated_by_emp_id);
CREATE INDEX IF NOT EXISTS idx_pronto_orders_chef_id ON pronto_orders (chef_id);
CREATE INDEX IF NOT EXISTS idx_pronto_orders_customer_id ON pronto_orders (customer_id);
CREATE INDEX IF NOT EXISTS idx_pronto_orders_delivery_waiter_id ON pronto_orders (delivery_waiter_id);
CREATE INDEX IF NOT EXISTS idx_pronto_orders_employee_id ON pronto_orders (employee_id);
CREATE INDEX IF NOT EXISTS idx_pronto_orders_waiter_id ON pronto_orders (waiter_id);
CREATE INDEX IF NOT EXISTS idx_pronto_recommendation_change_log_employee_id ON pronto_recommendation_change_log (employee_id);
CREATE INDEX IF NOT EXISTS idx_pronto_table_log_employee_id ON pronto_table_log (employee_id);
CREATE INDEX IF NOT EXISTS idx_pronto_table_log_session_id ON pronto_table_log (session_id);
CREATE INDEX IF NOT EXISTS idx_pronto_table_log_table_id ON pronto_table_log (table_id);
CREATE INDEX IF NOT EXISTS idx_pronto_table_transfer_requests_resolved_by_employee_id ON pronto_table_transfer_requests (resolved_by_employee_id);
CREATE INDEX IF NOT EXISTS idx_pronto_tables_area_id ON pronto_tables (area_id);
