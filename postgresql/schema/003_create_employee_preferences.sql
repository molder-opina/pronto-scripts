-- EmployeePreference: Preferencias de empleados
CREATE TABLE IF NOT EXISTS pronto_employee_preferences (
    employee_id INTEGER PRIMARY KEY REFERENCES pronto_employees(id) ON DELETE CASCADE,
    preferences_json JSONB NOT NULL DEFAULT '{}',
    updated_at TIMESTAMP DEFAULT NOW()
);
