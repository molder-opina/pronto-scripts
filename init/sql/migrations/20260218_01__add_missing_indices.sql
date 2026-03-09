-- Add missing indices for foreign keys, but only when the target table/column exists.

DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT *
        FROM (
            VALUES
                -- ('idx_pronto_business_info_updated_by', 'pronto_business_info', 'updated_by'),
                ('idx_pronto_dining_sessions_customer_id', 'pronto_dining_sessions', 'customer_id'),
                ('idx_pronto_dining_sessions_employee_id', 'pronto_dining_sessions', 'employee_id'),
                ('idx_pronto_feedback_customer_id', 'pronto_feedback', 'customer_id'),
                ('idx_pronto_kitchen_orders_order_id', 'pronto_kitchen_orders', 'order_id'),
                ('idx_pronto_menu_categories_parent_category_id', 'pronto_menu_categories', 'parent_category_id'),
                ('idx_pronto_modifier_groups_menu_item_id', 'pronto_modifier_groups', 'menu_item_id'),
                ('idx_pronto_modifiers_group_id', 'pronto_modifiers', 'group_id'),
                ('idx_pronto_order_items_delivered_by_employee_id', 'pronto_order_items', 'delivered_by_employee_id'),
                ('idx_pronto_order_items_menu_item_id', 'pronto_order_items', 'menu_item_id'),
                ('idx_pronto_order_status_history_changed_by', 'pronto_order_status_history', 'changed_by'),
                ('idx_pronto_order_status_labels_updated_by_emp_id', 'pronto_order_status_labels', 'updated_by_emp_id'),
                ('idx_pronto_orders_chef_id', 'pronto_orders', 'chef_id'),
                ('idx_pronto_orders_customer_id', 'pronto_orders', 'customer_id'),
                ('idx_pronto_orders_delivery_waiter_id', 'pronto_orders', 'delivery_waiter_id'),
                ('idx_pronto_orders_employee_id', 'pronto_orders', 'employee_id'),
                ('idx_pronto_orders_waiter_id', 'pronto_orders', 'waiter_id'),
                ('idx_pronto_recommendation_change_log_employee_id', 'pronto_recommendation_change_log', 'employee_id'),
                ('idx_pronto_table_log_employee_id', 'pronto_table_log', 'employee_id'),
                ('idx_pronto_table_log_session_id', 'pronto_table_log', 'session_id'),
                ('idx_pronto_table_log_table_id', 'pronto_table_log', 'table_id'),
                ('idx_pronto_table_transfer_requests_resolved_by_employee_id', 'pronto_table_transfer_requests', 'resolved_by_employee_id'),
                ('idx_pronto_tables_area_id', 'pronto_tables', 'area_id')
        ) AS planned(index_name, table_name, column_name)
    LOOP
        IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = rec.table_name
              AND column_name = rec.column_name
        ) THEN
            EXECUTE format(
                'CREATE INDEX IF NOT EXISTS %I ON %I (%I)',
                rec.index_name,
                rec.table_name,
                rec.column_name
            );
        END IF;
    END LOOP;
END $$;
