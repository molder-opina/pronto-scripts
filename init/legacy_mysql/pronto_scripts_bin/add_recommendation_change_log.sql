-- Migration: Add recommendation change log table
-- Description: Adds table to track changes in product recommendations

-- Create recommendation change log table
CREATE TABLE IF NOT EXISTS pronto_recommendation_change_log (
    id SERIAL PRIMARY KEY,
    menu_item_id INTEGER NOT NULL REFERENCES pronto_menu_items(id),
    period_key VARCHAR(50) NOT NULL,
    action VARCHAR(20) NOT NULL,
    employee_id INTEGER REFERENCES pronto_employees(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS ix_rec_log_menu_item ON pronto_recommendation_change_log(menu_item_id);
CREATE INDEX IF NOT EXISTS ix_rec_log_period ON pronto_recommendation_change_log(period_key);
CREATE INDEX IF NOT EXISTS ix_rec_log_created_at ON pronto_recommendation_change_log(created_at);

-- Add comment
COMMENT ON TABLE pronto_recommendation_change_log IS 'Historial de cambios en las recomendaciones de productos';
COMMENT ON COLUMN pronto_recommendation_change_log.action IS 'Acción realizada: added o removed';
