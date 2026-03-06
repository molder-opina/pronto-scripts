CREATE TABLE IF NOT EXISTS pronto_day_periods (
    id SERIAL PRIMARY KEY,
    period_key VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    icon VARCHAR(16),
    color VARCHAR(32),
    start_time VARCHAR(5) NOT NULL,
    end_time VARCHAR(5) NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT (now() AT TIME ZONE 'utc') NOT NULL,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT (now() AT TIME ZONE 'utc') NOT NULL
);

CREATE INDEX IF NOT EXISTS ix_day_period_display_order ON pronto_day_periods (display_order);

CREATE TABLE IF NOT EXISTS pronto_menu_item_day_periods (
    id SERIAL PRIMARY KEY,
    menu_item_id UUID NOT NULL REFERENCES pronto_menu_items(id) ON DELETE CASCADE,
    period_id INTEGER NOT NULL REFERENCES pronto_day_periods(id) ON DELETE CASCADE,
    tag_type VARCHAR(32) NOT NULL DEFAULT 'recommendation',
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT (now() AT TIME ZONE 'utc') NOT NULL,
    CONSTRAINT uq_menu_item_period_tag UNIQUE (menu_item_id, period_id, tag_type)
);

CREATE INDEX IF NOT EXISTS ix_menu_item_period_menu ON pronto_menu_item_day_periods (menu_item_id);
CREATE INDEX IF NOT EXISTS ix_menu_item_period_tag ON pronto_menu_item_day_periods (tag_type);
