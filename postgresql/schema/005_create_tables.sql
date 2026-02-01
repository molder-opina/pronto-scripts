-- Table: Mesas
CREATE TABLE IF NOT EXISTS pronto_tables (
    id SERIAL PRIMARY KEY,
    table_number VARCHAR(50) NOT NULL UNIQUE,
    qr_code VARCHAR(100) NOT NULL UNIQUE,
    area_id INTEGER NOT NULL REFERENCES pronto_areas(id),
    capacity INTEGER NOT NULL DEFAULT 4,
    status VARCHAR(32) NOT NULL DEFAULT 'available',
    position_x INTEGER,
    position_y INTEGER,
    shape VARCHAR(32) DEFAULT 'square',
    notes TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_table_number ON pronto_tables(table_number);
CREATE INDEX IF NOT EXISTS ix_table_qr_code ON pronto_tables(qr_code);
CREATE INDEX IF NOT EXISTS ix_table_status ON pronto_tables(status);
CREATE INDEX IF NOT EXISTS ix_table_area ON pronto_tables(area_id);
