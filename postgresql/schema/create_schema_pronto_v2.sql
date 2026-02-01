-- =============================================================================
-- ESQUEMA COMPLETO DE PRONTO - BASADO EN models.py ACTUAL
-- =============================================================================
-- Script generado automáticamente basándose en los modelos ORM actuales
-- =============================================================================

BEGIN;

-- Extensiones requeridas
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- TABLAS PRINCIPALES
-- =============================================================================

-- Customer: Clientes con campos encriptados
CREATE TABLE IF NOT EXISTS pronto_customers (
    id SERIAL PRIMARY KEY,
    name_encrypted TEXT NOT NULL,
    email_encrypted TEXT,
    phone_encrypted TEXT,
    email_hash VARCHAR(128) UNIQUE,
    contact_hash VARCHAR(128),
    anon_id VARCHAR(64) UNIQUE,
    physical_description TEXT,
    avatar VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_customer_email_hash ON pronto_customers(email_hash);
CREATE INDEX IF NOT EXISTS ix_customer_created_at ON pronto_customers(created_at);

-- Employee: Empleados
CREATE TABLE IF NOT EXISTS pronto_employees (
    id SERIAL PRIMARY KEY,
    name_encrypted TEXT NOT NULL,
    email_encrypted TEXT NOT NULL,
    email_hash VARCHAR(128) UNIQUE NOT NULL,
    allow_scopes JSONB,
    auth_hash VARCHAR(128) NOT NULL,
    role VARCHAR(64) NOT NULL DEFAULT 'staff',
    additional_roles TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    signed_in_at TIMESTAMP,
    last_activity_at TIMESTAMP,
    preferences JSONB
);

CREATE INDEX IF NOT EXISTS ix_employee_email_hash ON pronto_employees(email_hash);
CREATE INDEX IF NOT EXISTS ix_employee_role_active ON pronto_employees(role, is_active);
CREATE INDEX IF NOT EXISTS ix_employee_created_at ON pronto_employees(created_at);

-- EmployeePreference: Preferencias de empleados (tabla separada)
CREATE TABLE IF NOT EXISTS pronto_employee_preferences (
    employee_id INTEGER PRIMARY KEY REFERENCES pronto_employees(id) ON DELETE CASCADE,
    preferences_json JSONB NOT NULL DEFAULT '{}',
    updated_at TIMESTAMP DEFAULT NOW()
);

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

-- DiningSession: Sesiones de comedor
CREATE TABLE IF NOT EXISTS pronto_dining_sessions (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES pronto_customers(id),
    table_id INTEGER REFERENCES pronto_tables(id),
    status VARCHAR(32) NOT NULL DEFAULT 'open',
    table_number VARCHAR(32),
    notes TEXT,
    opened_at TIMESTAMP NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMP,
    expires_at TIMESTAMP,
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    tip_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    total_paid NUMERIC(10, 2) NOT NULL DEFAULT 0,
    payment_method VARCHAR(32),
    payment_reference VARCHAR(128),
    payment_confirmed_at TIMESTAMP,
    tip_requested_at TIMESTAMP,
    tip_confirmed_at TIMESTAMP,
    check_requested_at TIMESTAMP,
    feedback_requested_at TIMESTAMP,
    feedback_completed_at TIMESTAMP,
    email VARCHAR(255)
);

CREATE INDEX IF NOT EXISTS ix_dining_session_status ON pronto_dining_sessions(status);
CREATE INDEX IF NOT EXISTS ix_dining_session_customer_status ON pronto_dining_sessions(customer_id, status);
CREATE INDEX IF NOT EXISTS ix_dining_session_opened_at ON pronto_dining_sessions(opened_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_dining_session_open_table ON pronto_dining_sessions(table_id) WHERE status = 'open';

-- RoutePermission: Permisos de rutas
CREATE TABLE IF NOT EXISTS pronto_route_permissions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(64) NOT NULL UNIQUE,
    description TEXT,
    display_name VARCHAR(120) NOT NULL,
    app_target VARCHAR(32) NOT NULL
);

-- EmployeeRouteAccess: Acceso a rutas por empleado
CREATE TABLE IF NOT EXISTS pronto_employee_route_access (
    employee_id INTEGER NOT NULL REFERENCES pronto_employees(id),
    route_permission_id INTEGER NOT NULL REFERENCES pronto_route_permissions(id),
    granted_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (employee_id, route_permission_id)
);

-- MenuCategory: Categorías del menú
CREATE TABLE IF NOT EXISTS pronto_menu_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE,
    description TEXT,
    display_order INTEGER NOT NULL DEFAULT 0
);

-- MenuItem: Productos del menú
CREATE TABLE IF NOT EXISTS pronto_menu_items (
    id SERIAL PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    image_path VARCHAR(255),
    category_id INTEGER NOT NULL REFERENCES pronto_menu_categories(id),
    preparation_time_minutes INTEGER DEFAULT 15,
    is_breakfast_recommended BOOLEAN NOT NULL DEFAULT FALSE,
    is_afternoon_recommended BOOLEAN NOT NULL DEFAULT FALSE,
    is_night_recommended BOOLEAN NOT NULL DEFAULT FALSE,
    track_inventory BOOLEAN NOT NULL DEFAULT FALSE,
    stock_quantity INTEGER,
    low_stock_threshold INTEGER DEFAULT 10,
    is_quick_serve BOOLEAN NOT NULL DEFAULT FALSE
);

-- ModifierGroup: Grupos de modificadores
CREATE TABLE IF NOT EXISTS pronto_modifier_groups (
    id SERIAL PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    min_selection INTEGER NOT NULL DEFAULT 0,
    max_selection INTEGER NOT NULL DEFAULT 1,
    is_required BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INTEGER NOT NULL DEFAULT 0
);

-- Modifier: Modificadores individuales
CREATE TABLE IF NOT EXISTS pronto_modifiers (
    id SERIAL PRIMARY KEY,
    group_id INTEGER NOT NULL REFERENCES pronto_modifier_groups(id),
    name VARCHAR(120) NOT NULL,
    price_adjustment NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (price_adjustment >= 0),
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INTEGER NOT NULL DEFAULT 0
);

-- MenuItemModifierGroup: Relación productos-modificadores
CREATE TABLE IF NOT EXISTS pronto_menu_item_modifier_groups (
    menu_item_id INTEGER NOT NULL REFERENCES pronto_menu_items(id),
    modifier_group_id INTEGER NOT NULL REFERENCES pronto_modifier_groups(id),
    display_order INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (menu_item_id, modifier_group_id)
);

-- DayPeriod: Períodos del día
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
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_day_period_display_order ON pronto_day_periods(display_order);

-- MenuItemDayPeriod: Relación items-períodos
CREATE TABLE IF NOT EXISTS pronto_menu_item_day_periods (
    id SERIAL PRIMARY KEY,
    menu_item_id INTEGER NOT NULL REFERENCES pronto_menu_items(id),
    period_id INTEGER NOT NULL REFERENCES pronto_day_periods(id),
    tag_type VARCHAR(32) NOT NULL DEFAULT 'recommendation',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(menu_item_id, period_id, tag_type)
);

CREATE INDEX IF NOT EXISTS ix_menu_item_period_menu ON pronto_menu_item_day_periods(menu_item_id);
CREATE INDEX IF NOT EXISTS ix_menu_item_period_tag ON pronto_menu_item_day_periods(tag_type);

-- Order: Órdenes
CREATE TABLE IF NOT EXISTS pronto_orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES pronto_customers(id),
    customer_email VARCHAR(255),
    session_id INTEGER NOT NULL REFERENCES pronto_dining_sessions(id),
    workflow_status VARCHAR(32) NOT NULL DEFAULT 'new',
    payment_status VARCHAR(32) NOT NULL DEFAULT 'unpaid',
    payment_method VARCHAR(32),
    payment_reference VARCHAR(128),
    payment_meta JSONB,
    notes TEXT,
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    tip_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    waiter_id INTEGER REFERENCES pronto_employees(id),
    chef_id INTEGER REFERENCES pronto_employees(id),
    delivery_waiter_id INTEGER REFERENCES pronto_employees(id),
    accepted_at TIMESTAMP,
    waiter_accepted_at TIMESTAMP,
    chef_accepted_at TIMESTAMP,
    ready_at TIMESTAMP,
    delivered_at TIMESTAMP,
    check_requested_at TIMESTAMP,
    feedback_requested_at TIMESTAMP,
    feedback_completed_at TIMESTAMP,
    paid_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_order_workflow_status ON pronto_orders(workflow_status);
CREATE INDEX IF NOT EXISTS ix_order_status_created ON pronto_orders(workflow_status, created_at);
CREATE INDEX IF NOT EXISTS ix_order_session_id ON pronto_orders(session_id);
CREATE INDEX IF NOT EXISTS ix_order_waiter_id ON pronto_orders(waiter_id);
CREATE INDEX IF NOT EXISTS ix_order_chef_id ON pronto_orders(chef_id);
CREATE INDEX IF NOT EXISTS ix_order_delivery_waiter_id ON pronto_orders(delivery_waiter_id);
CREATE INDEX IF NOT EXISTS ix_order_created_at ON pronto_orders(created_at);

-- OrderItem: Items de orden
CREATE TABLE IF NOT EXISTS pronto_order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES pronto_orders(id),
    menu_item_id INTEGER NOT NULL REFERENCES pronto_menu_items(id),
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price NUMERIC(10, 2) NOT NULL,
    special_instructions TEXT,
    delivered_quantity INTEGER NOT NULL DEFAULT 0,
    is_fully_delivered BOOLEAN NOT NULL DEFAULT FALSE,
    delivered_at TIMESTAMP,
    delivered_by_employee_id INTEGER REFERENCES pronto_employees(id)
);

CREATE INDEX IF NOT EXISTS ix_order_item_order_id ON pronto_order_items(order_id);
CREATE INDEX IF NOT EXISTS ix_order_item_menu_item_id ON pronto_order_items(menu_item_id);
CREATE INDEX IF NOT EXISTS ix_order_item_delivery_status ON pronto_order_items(is_fully_delivered, delivered_at);

-- OrderItemModifier: Modificadores de items
CREATE TABLE IF NOT EXISTS pronto_order_item_modifiers (
    id SERIAL PRIMARY KEY,
    order_item_id INTEGER NOT NULL REFERENCES pronto_order_items(id),
    modifier_id INTEGER NOT NULL REFERENCES pronto_modifiers(id),
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price_adjustment NUMERIC(10, 2) NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS ix_order_item_modifier_item_id ON pronto_order_item_modifiers(order_item_id);
CREATE INDEX IF NOT EXISTS ix_order_item_modifier_modifier_id ON pronto_order_item_modifiers(modifier_id);

-- OrderStatusHistory: Historial de estados
CREATE TABLE IF NOT EXISTS pronto_order_status_history (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES pronto_orders(id),
    status VARCHAR(32) NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- OrderStatusLabel: Etiquetas de estado editables
CREATE TABLE IF NOT EXISTS pronto_order_status_labels (
    status_key VARCHAR(32) PRIMARY KEY,
    client_label VARCHAR(120) NOT NULL,
    employee_label VARCHAR(120) NOT NULL,
    admin_desc TEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_by_emp_id INTEGER REFERENCES pronto_employees(id),
    version INTEGER NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_order_status_label_key ON pronto_order_status_labels(status_key);

-- OrderModification: Modificaciones de órdenes
CREATE TABLE IF NOT EXISTS pronto_order_modifications (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES pronto_orders(id),
    initiated_by_role VARCHAR(32) NOT NULL,
    initiated_by_customer_id INTEGER REFERENCES pronto_customers(id),
    initiated_by_employee_id INTEGER REFERENCES pronto_employees(id),
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    changes_data JSONB NOT NULL DEFAULT '{}',
    reviewed_by_customer_id INTEGER REFERENCES pronto_customers(id),
    reviewed_by_employee_id INTEGER REFERENCES pronto_employees(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    reviewed_at TIMESTAMP,
    applied_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_order_modification_order ON pronto_order_modifications(order_id);
CREATE INDEX IF NOT EXISTS ix_order_modification_status ON pronto_order_modifications(status);
CREATE INDEX IF NOT EXISTS ix_order_modification_created_at ON pronto_order_modifications(created_at);

-- Notification: Notificaciones
CREATE TABLE IF NOT EXISTS pronto_notifications (
    id SERIAL PRIMARY KEY,
    notification_type VARCHAR(64) NOT NULL,
    recipient_type VARCHAR(32) NOT NULL,
    recipient_id INTEGER,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    data JSONB,
    status VARCHAR(32) NOT NULL DEFAULT 'unread',
    priority VARCHAR(32) NOT NULL DEFAULT 'normal',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    read_at TIMESTAMP,
    dismissed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_notification_recipient_type_status ON pronto_notifications(recipient_type, recipient_id, status);
CREATE INDEX IF NOT EXISTS ix_notification_created_at ON pronto_notifications(created_at);
CREATE INDEX IF NOT EXISTS ix_notification_type ON pronto_notifications(notification_type);

-- Promotion: Promociones
CREATE TABLE IF NOT EXISTS pronto_promotions (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    promotion_type VARCHAR(32) NOT NULL,
    discount_percentage NUMERIC(5, 2),
    discount_amount NUMERIC(10, 2),
    min_purchase_amount NUMERIC(10, 2),
    applies_to VARCHAR(32) NOT NULL DEFAULT 'products',
    applicable_tags JSONB,
    applicable_products JSONB,
    valid_from TIMESTAMP NOT NULL,
    valid_until TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    banner_message VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
    CHECK (discount_amount >= 0)
);

CREATE INDEX IF NOT EXISTS ix_promotion_active_dates ON pronto_promotions(is_active, valid_from, valid_until);

-- DiscountCode: Códigos de descuento
CREATE TABLE IF NOT EXISTS pronto_discount_codes (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    discount_type VARCHAR(32) NOT NULL,
    discount_percentage NUMERIC(5, 2),
    discount_amount NUMERIC(10, 2),
    min_purchase_amount NUMERIC(10, 2),
    usage_limit INTEGER,
    times_used INTEGER NOT NULL DEFAULT 0,
    applies_to VARCHAR(32) NOT NULL DEFAULT 'products',
    applicable_tags JSONB,
    applicable_products JSONB,
    valid_from TIMESTAMP NOT NULL,
    valid_until TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
    CHECK (discount_amount >= 0),
    CHECK (usage_limit >= 0),
    CHECK (times_used >= 0)
);

CREATE INDEX IF NOT EXISTS ix_discount_code ON pronto_discount_codes(code);
CREATE INDEX IF NOT EXISTS ix_discount_active_dates ON pronto_discount_codes(is_active, valid_from, valid_until);

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

-- WaiterCall: Llamadas de mesero
CREATE TABLE IF NOT EXISTS pronto_waiter_calls (
    id SERIAL PRIMARY KEY,
    session_id INTEGER REFERENCES pronto_dining_sessions(id),
    table_number VARCHAR(32),
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    confirmed_at TIMESTAMP,
    confirmed_by INTEGER REFERENCES pronto_employees(id),
    cancelled_at TIMESTAMP,
    notes TEXT
);

CREATE INDEX IF NOT EXISTS ix_waiter_call_session ON pronto_waiter_calls(session_id);
CREATE INDEX IF NOT EXISTS ix_waiter_call_status ON pronto_waiter_calls(status);
CREATE INDEX IF NOT EXISTS ix_waiter_call_created_at ON pronto_waiter_calls(created_at);
CREATE INDEX IF NOT EXISTS ix_waiter_call_confirmed_by ON pronto_waiter_calls(confirmed_by);

-- SupportTicket: Tickets de soporte
CREATE TABLE IF NOT EXISTS pronto_support_tickets (
    id SERIAL PRIMARY KEY,
    channel VARCHAR(32) DEFAULT 'client' NOT NULL,
    name_encrypted TEXT NOT NULL,
    email_encrypted TEXT NOT NULL,
    description_encrypted TEXT NOT NULL,
    page_url VARCHAR(255),
    user_agent VARCHAR(255),
    status VARCHAR(32) DEFAULT 'open' NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_support_ticket_status ON pronto_support_tickets(status);
CREATE INDEX IF NOT EXISTS ix_support_ticket_created_at ON pronto_support_tickets(created_at);
CREATE INDEX IF NOT EXISTS ix_support_ticket_channel ON pronto_support_tickets(channel);

-- ProductSchedule: Horarios de productos
CREATE TABLE IF NOT EXISTS pronto_product_schedules (
    id SERIAL PRIMARY KEY,
    menu_item_id INTEGER NOT NULL REFERENCES pronto_menu_items(id),
    day_of_week INTEGER,
    start_time VARCHAR(5),
    end_time VARCHAR(5),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_product_schedule_item ON pronto_product_schedules(menu_item_id);
CREATE INDEX IF NOT EXISTS ix_product_schedule_active ON pronto_product_schedules(is_active);
CREATE INDEX IF NOT EXISTS ix_product_schedule_day_active ON pronto_product_schedules(day_of_week, is_active);

-- SplitBill: División de cuentas
CREATE TABLE IF NOT EXISTS pronto_split_bills (
    id SERIAL PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES pronto_dining_sessions(id),
    split_type VARCHAR(32) NOT NULL DEFAULT 'by_items',
    status VARCHAR(32) NOT NULL DEFAULT 'active',
    number_of_people INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_split_bill_session ON pronto_split_bills(session_id);
CREATE INDEX IF NOT EXISTS ix_split_bill_status ON pronto_split_bills(status);

-- SplitBillPerson: Personas en split
CREATE TABLE IF NOT EXISTS pronto_split_bill_people (
    id SERIAL PRIMARY KEY,
    split_bill_id INTEGER NOT NULL REFERENCES pronto_split_bills(id),
    person_name VARCHAR(100) NOT NULL,
    person_number INTEGER NOT NULL,
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    tip_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    payment_status VARCHAR(32) NOT NULL DEFAULT 'unpaid',
    customer_email VARCHAR(255),
    payment_method VARCHAR(32),
    payment_reference VARCHAR(128),
    paid_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_split_bill_person_split ON pronto_split_bill_people(split_bill_id);

-- SplitBillAssignment: Asignaciones de items
CREATE TABLE IF NOT EXISTS pronto_split_bill_assignments (
    id SERIAL PRIMARY KEY,
    split_bill_id INTEGER NOT NULL REFERENCES pronto_split_bills(id),
    person_id INTEGER NOT NULL REFERENCES pronto_split_bill_people(id),
    order_item_id INTEGER NOT NULL REFERENCES pronto_order_items(id),
    quantity_portion NUMERIC(10, 2) NOT NULL DEFAULT 1.0,
    amount NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_split_assignment_split ON pronto_split_bill_assignments(split_bill_id);
CREATE INDEX IF NOT EXISTS ix_split_assignment_person ON pronto_split_bill_assignments(person_id);
CREATE INDEX IF NOT EXISTS ix_split_assignment_item ON pronto_split_bill_assignments(order_item_id);

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

-- CustomRole: Roles personalizados
CREATE TABLE IF NOT EXISTS pronto_custom_roles (
    id SERIAL PRIMARY KEY,
    role_code VARCHAR(64) NOT NULL UNIQUE,
    role_name VARCHAR(100) NOT NULL,
    description TEXT,
    color VARCHAR(20),
    icon VARCHAR(50),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by INTEGER REFERENCES pronto_employees(id)
);

CREATE INDEX IF NOT EXISTS ix_custom_role_code ON pronto_custom_roles(role_code);
CREATE INDEX IF NOT EXISTS ix_custom_role_active ON pronto_custom_roles(is_active);

-- RolePermission: Permisos de roles personalizados
CREATE TABLE IF NOT EXISTS pronto_role_permissions (
    id SERIAL PRIMARY KEY,
    custom_role_id INTEGER NOT NULL REFERENCES pronto_custom_roles(id),
    resource_type VARCHAR(50) NOT NULL,
    action VARCHAR(50) NOT NULL,
    allowed BOOLEAN NOT NULL DEFAULT TRUE,
    conditions TEXT
);

CREATE INDEX IF NOT EXISTS ix_role_permission_role ON pronto_role_permissions(custom_role_id);
CREATE INDEX IF NOT EXISTS ix_role_permission_resource ON pronto_role_permissions(resource_type, action);

-- Feedback: Feedback de clientes
CREATE TABLE IF NOT EXISTS pronto_feedback (
    id SERIAL PRIMARY KEY,
    session_id INTEGER NOT NULL REFERENCES pronto_dining_sessions(id),
    customer_id INTEGER REFERENCES pronto_customers(id),
    employee_id INTEGER REFERENCES pronto_employees(id),
    category VARCHAR(50) NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    is_anonymous BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_feedback_session ON pronto_feedback(session_id);
CREATE INDEX IF NOT EXISTS ix_feedback_employee ON pronto_feedback(employee_id);
CREATE INDEX IF NOT EXISTS ix_feedback_category ON pronto_feedback(category);
CREATE INDEX IF NOT EXISTS ix_feedback_rating ON pronto_feedback(rating);
CREATE INDEX IF NOT EXISTS ix_feedback_created_at ON pronto_feedback(created_at);

-- WaiterTableAssignment: Asignación meseros-mesas
CREATE TABLE IF NOT EXISTS pronto_waiter_table_assignments (
    id SERIAL PRIMARY KEY,
    waiter_id INTEGER NOT NULL REFERENCES pronto_employees(id),
    table_id INTEGER NOT NULL REFERENCES pronto_tables(id),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    assigned_at TIMESTAMP NOT NULL DEFAULT NOW(),
    unassigned_at TIMESTAMP,
    notes TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_waiter_table_active ON pronto_waiter_table_assignments(waiter_id, table_id) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS ix_waiter_table_assignment_waiter ON pronto_waiter_table_assignments(waiter_id);
CREATE INDEX IF NOT EXISTS ix_waiter_table_assignment_table ON pronto_waiter_table_assignments(table_id);
CREATE INDEX IF NOT EXISTS ix_waiter_table_assignment_active ON pronto_waiter_table_assignments(is_active);

-- TableTransferRequest: Transferencias de mesa
CREATE TABLE IF NOT EXISTS pronto_table_transfer_requests (
    id SERIAL PRIMARY KEY,
    table_id INTEGER NOT NULL REFERENCES pronto_tables(id),
    from_waiter_id INTEGER NOT NULL REFERENCES pronto_employees(id),
    to_waiter_id INTEGER NOT NULL REFERENCES pronto_employees(id),
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    transfer_orders BOOLEAN NOT NULL DEFAULT FALSE,
    message TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMP,
    resolved_by_employee_id INTEGER REFERENCES pronto_employees(id)
);

CREATE INDEX IF NOT EXISTS ix_table_transfer_from_waiter ON pronto_table_transfer_requests(from_waiter_id);
CREATE INDEX IF NOT EXISTS ix_table_transfer_to_waiter ON pronto_table_transfer_requests(to_waiter_id);
CREATE INDEX IF NOT EXISTS ix_table_transfer_table ON pronto_table_transfer_requests(table_id);
CREATE INDEX IF NOT EXISTS ix_table_transfer_status ON pronto_table_transfer_requests(status);
CREATE INDEX IF NOT EXISTS ix_table_transfer_created ON pronto_table_transfer_requests(created_at);

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

-- KeyboardShortcut: Atajos de teclado
CREATE TABLE IF NOT EXISTS pronto_keyboard_shortcuts (
    id SERIAL PRIMARY KEY,
    combo VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(200) NOT NULL,
    category VARCHAR(50) NOT NULL DEFAULT 'General',
    callback_function VARCHAR(100) NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    prevent_default BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_shortcut_combo ON pronto_keyboard_shortcuts(combo);
CREATE INDEX IF NOT EXISTS ix_shortcut_enabled ON pronto_keyboard_shortcuts(is_enabled);

-- FeedbackQuestion: Preguntas de feedback
CREATE TABLE IF NOT EXISTS pronto_feedback_questions (
    id SERIAL PRIMARY KEY,
    question_text TEXT NOT NULL,
    question_type VARCHAR(20) NOT NULL DEFAULT 'rating',
    category VARCHAR(50),
    is_required BOOLEAN NOT NULL DEFAULT TRUE,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    min_rating INTEGER NOT NULL DEFAULT 1,
    max_rating INTEGER NOT NULL DEFAULT 5,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_feedback_question_enabled ON pronto_feedback_questions(is_enabled);
CREATE INDEX IF NOT EXISTS ix_feedback_question_order ON pronto_feedback_questions(sort_order);

-- FeedbackToken: Tokens para feedback
CREATE TABLE IF NOT EXISTS pronto_feedback_tokens (
    id SERIAL PRIMARY KEY,
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    order_id INTEGER NOT NULL REFERENCES pronto_orders(id) ON DELETE CASCADE,
    session_id INTEGER NOT NULL REFERENCES pronto_dining_sessions(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES pronto_customers(id) ON DELETE CASCADE,
    email VARCHAR(255),
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    email_sent_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_feedback_token_order ON pronto_feedback_tokens(order_id);
CREATE INDEX IF NOT EXISTS ix_feedback_token_session ON pronto_feedback_tokens(session_id);
CREATE INDEX IF NOT EXISTS ix_feedback_token_user ON pronto_feedback_tokens(user_id);
CREATE INDEX IF NOT EXISTS ix_feedback_token_hash ON pronto_feedback_tokens(token_hash);
CREATE INDEX IF NOT EXISTS ix_feedback_token_expires ON pronto_feedback_tokens(expires_at);
CREATE INDEX IF NOT EXISTS ix_feedback_token_used ON pronto_feedback_tokens(used_at);

-- SystemRole: Roles del sistema
CREATE TABLE IF NOT EXISTS pronto_system_roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(64) NOT NULL UNIQUE,
    display_name VARCHAR(120) NOT NULL,
    description TEXT,
    is_custom BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- SystemPermission: Permisos del sistema
CREATE TABLE IF NOT EXISTS pronto_system_permissions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(64) NOT NULL UNIQUE,
    category VARCHAR(32) NOT NULL,
    description TEXT
);

-- RolePermissionBinding: Vinculación rol-permiso
CREATE TABLE IF NOT EXISTS pronto_role_permission_bindings (
    role_id INTEGER NOT NULL REFERENCES pronto_system_roles(id),
    permission_id INTEGER NOT NULL REFERENCES pronto_system_permissions(id),
    PRIMARY KEY (role_id, permission_id)
);

-- SuperAdminHandoffToken: Tokens de handoff
CREATE TABLE IF NOT EXISTS super_admin_handoff_tokens (
    id SERIAL PRIMARY KEY,
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    employee_id INTEGER NOT NULL REFERENCES pronto_employees(id),
    target_scope VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE,
    ip_address VARCHAR(45),
    user_agent TEXT
);

CREATE INDEX IF NOT EXISTS ix_handoff_token_hash ON super_admin_handoff_tokens(token_hash);
CREATE INDEX IF NOT EXISTS ix_handoff_expires_at ON super_admin_handoff_tokens(expires_at);

-- AuditLog: Log de auditoría
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES pronto_employees(id),
    action VARCHAR(50) NOT NULL,
    details TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_audit_employee_id ON audit_logs(employee_id);
CREATE INDEX IF NOT EXISTS ix_audit_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS ix_audit_created_at ON audit_logs(created_at);

-- SystemSetting: Configuraciones del sistema
CREATE TABLE IF NOT EXISTS pronto_system_settings (
    key VARCHAR(100) PRIMARY KEY,
    value TEXT NOT NULL,
    value_type VARCHAR(20) NOT NULL DEFAULT 'string',
    description TEXT,
    category VARCHAR(50) NOT NULL DEFAULT 'general',
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

COMMIT;

-- Resumen
SELECT 'Schema PRONTO actualizado' AS status, COUNT(*) AS total_tables
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name LIKE 'pronto_%' 
   OR table_name = 'super_admin_handoff_tokens'
   OR table_name = 'audit_logs';
