-- Area: Áreas del restaurante
CREATE TABLE IF NOT EXISTS pronto_areas (
    id SERIAL PRIMARY KEY,
    name VARCHAR(120) NOT NULL UNIQUE,
    description TEXT,
    color VARCHAR(20) NOT NULL DEFAULT '#ff6b35',
    prefix VARCHAR(10) NOT NULL UNIQUE,
    background_image TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_area_name ON pronto_areas(name);
CREATE INDEX IF NOT EXISTS ix_area_prefix ON pronto_areas(prefix);
CREATE INDEX IF NOT EXISTS ix_area_active ON pronto_areas(is_active);
