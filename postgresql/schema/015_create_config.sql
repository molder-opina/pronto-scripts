-- BusinessConfig: Configuraciones del negocio
CREATE TABLE IF NOT EXISTS pronto_business_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(100) NOT NULL UNIQUE,
    config_value JSONB NOT NULL,
    value_type VARCHAR(32) NOT NULL DEFAULT 'string',
    category VARCHAR(100) NOT NULL DEFAULT 'general',
    display_name VARCHAR(200) NOT NULL,
    description TEXT,
    min_value NUMERIC(10, 2),
    max_value NUMERIC(10, 2),
    unit VARCHAR(32),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_by INTEGER REFERENCES pronto_employees(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_business_config_key ON pronto_business_config(config_key);
CREATE INDEX IF NOT EXISTS ix_business_config_category ON pronto_business_config(category);

-- Secret: Secretos
CREATE TABLE IF NOT EXISTS pronto_secrets (
    id SERIAL PRIMARY KEY,
    secret_key VARCHAR(120) NOT NULL UNIQUE,
    secret_value TEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_secret_key ON pronto_secrets(secret_key);
