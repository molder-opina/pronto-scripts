-- Migration: create_order_status_labels_table
-- Description: Create missing pronto_order_status_labels table
-- Created: 2026-02-15

CREATE TABLE IF NOT EXISTS pronto_order_status_labels (
    status_key VARCHAR(50) PRIMARY KEY,
    client_label VARCHAR(100),
    employee_label VARCHAR(100),
    admin_desc TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_by_emp_id UUID REFERENCES pronto_employees(id),
    version INTEGER DEFAULT 1
);

-- Insert default labels
INSERT INTO pronto_order_status_labels (status_key, client_label, employee_label, admin_desc) VALUES
('new', 'Pendiente', 'Nueva', 'Orden creada, esperando aceptación'),
('queued', 'En Cola', 'En Cola', 'Orden aceptada, esperando preparación'),
('preparing', 'Preparando', 'Preparando', 'Chef trabajando en la orden'),
('ready', 'Lista', 'Lista', 'Orden lista para servir'),
('delivered', 'Entregada', 'Entregada', 'Orden entregada al cliente'),
('paid', 'Pagada', 'Pagada', 'Orden pagada y cerrada'),
('cancelled', 'Cancelada', 'Cancelada', 'Orden cancelada')
ON CONFLICT (status_key) DO NOTHING;
