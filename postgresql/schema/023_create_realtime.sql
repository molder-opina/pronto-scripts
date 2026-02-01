-- RealtimeEvent: Eventos en tiempo real
CREATE TABLE IF NOT EXISTS pronto_realtime_events (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(100) NOT NULL,
    payload TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_realtime_event_type ON pronto_realtime_events(event_type);
CREATE INDEX IF NOT EXISTS ix_realtime_event_created_at ON pronto_realtime_events(created_at);

-- RecommendationChangeLog: Log de cambios en recomendaciones
CREATE TABLE IF NOT EXISTS pronto_recommendation_change_log (
    id SERIAL PRIMARY KEY,
    menu_item_id INTEGER NOT NULL REFERENCES pronto_menu_items(id),
    period_key VARCHAR(50) NOT NULL,
    action VARCHAR(20) NOT NULL,
    employee_id INTEGER REFERENCES pronto_employees(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_rec_log_menu_item ON pronto_recommendation_change_log(menu_item_id);
CREATE INDEX IF NOT EXISTS ix_rec_log_period ON pronto_recommendation_change_log(period_key);
CREATE INDEX IF NOT EXISTS ix_rec_log_created_at ON pronto_recommendation_change_log(created_at);
