-- BusinessInfo: Información del negocio (singleton)
CREATE TABLE IF NOT EXISTS pronto_business_info (
    id SERIAL PRIMARY KEY,
    business_name VARCHAR(200) NOT NULL,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    phone VARCHAR(50),
    email VARCHAR(200),
    website VARCHAR(200),
    logo_url VARCHAR(500),
    description TEXT,
    currency VARCHAR(10) NOT NULL DEFAULT 'MXN',
    timezone VARCHAR(50) NOT NULL DEFAULT 'America/Mexico_City',
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_by INTEGER REFERENCES pronto_employees(id)
);

-- BusinessSchedule: Horario del negocio
CREATE TABLE IF NOT EXISTS pronto_business_schedule (
    id SERIAL PRIMARY KEY,
    day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
    is_open BOOLEAN NOT NULL DEFAULT TRUE,
    open_time VARCHAR(10),
    close_time VARCHAR(10),
    notes VARCHAR(200)
);

CREATE INDEX IF NOT EXISTS ix_business_schedule_day ON pronto_business_schedule(day_of_week);
