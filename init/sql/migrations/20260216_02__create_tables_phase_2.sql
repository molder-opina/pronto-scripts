-- Migration: Create missing core tables (Phase 2)
-- Date: 2026-02-16
-- Description: Creates 15 missing tables including split bills, custom roles, feedback, and audit logs.

BEGIN;

-- 1. pronto_table_transfer_requests
CREATE TABLE IF NOT EXISTS pronto_table_transfer_requests (
    id SERIAL PRIMARY KEY,
    table_id UUID NOT NULL REFERENCES pronto_tables(id),
    from_waiter_id UUID NOT NULL REFERENCES pronto_employees(id),
    to_waiter_id UUID NOT NULL REFERENCES pronto_employees(id),
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    transfer_orders BOOLEAN NOT NULL DEFAULT FALSE,
    message TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    resolved_at TIMESTAMP WITHOUT TIME ZONE,
    resolved_by_employee_id UUID REFERENCES pronto_employees(id)
);
CREATE INDEX IF NOT EXISTS ix_table_transfer_from_waiter ON pronto_table_transfer_requests(from_waiter_id);
CREATE INDEX IF NOT EXISTS ix_table_transfer_to_waiter ON pronto_table_transfer_requests(to_waiter_id);
CREATE INDEX IF NOT EXISTS ix_table_transfer_table ON pronto_table_transfer_requests(table_id);
CREATE INDEX IF NOT EXISTS ix_table_transfer_status ON pronto_table_transfer_requests(status);
CREATE INDEX IF NOT EXISTS ix_table_transfer_created ON pronto_table_transfer_requests(created_at);

-- 2. pronto_feedback_questions
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
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_feedback_question_enabled ON pronto_feedback_questions(is_enabled);
CREATE INDEX IF NOT EXISTS ix_feedback_question_order ON pronto_feedback_questions(sort_order);

-- 3. pronto_feedback_tokens
CREATE TABLE IF NOT EXISTS pronto_feedback_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token_hash VARCHAR(128) NOT NULL UNIQUE,
    order_id UUID NOT NULL REFERENCES pronto_orders(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES pronto_dining_sessions(id) ON DELETE CASCADE,
    user_id UUID REFERENCES pronto_customers(id) ON DELETE CASCADE,
    email VARCHAR(255),
    expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    used_at TIMESTAMP WITHOUT TIME ZONE,
    email_sent_at TIMESTAMP WITHOUT TIME ZONE,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_feedback_token_order ON pronto_feedback_tokens(order_id);
CREATE INDEX IF NOT EXISTS ix_feedback_token_session ON pronto_feedback_tokens(session_id);
CREATE INDEX IF NOT EXISTS ix_feedback_token_user ON pronto_feedback_tokens(user_id);
CREATE INDEX IF NOT EXISTS ix_feedback_token_hash ON pronto_feedback_tokens(token_hash);
CREATE INDEX IF NOT EXISTS ix_feedback_token_expires ON pronto_feedback_tokens(expires_at);
CREATE INDEX IF NOT EXISTS ix_feedback_token_used ON pronto_feedback_tokens(used_at);

-- 4. audit_logs
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID REFERENCES pronto_employees(id),
    action VARCHAR(50) NOT NULL,
    details TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_audit_employee_id ON audit_logs(employee_id);
CREATE INDEX IF NOT EXISTS ix_audit_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS ix_audit_created_at ON audit_logs(created_at);

-- 5. pronto_recommendation_change_log
CREATE TABLE IF NOT EXISTS pronto_recommendation_change_log (
    id SERIAL PRIMARY KEY,
    menu_item_id UUID NOT NULL REFERENCES pronto_menu_items(id),
    period_key VARCHAR(50) NOT NULL,
    action VARCHAR(20) NOT NULL,
    employee_id UUID REFERENCES pronto_employees(id),
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_rec_log_menu_item ON pronto_recommendation_change_log(menu_item_id);
CREATE INDEX IF NOT EXISTS ix_rec_log_period ON pronto_recommendation_change_log(period_key);
CREATE INDEX IF NOT EXISTS ix_rec_log_created_at ON pronto_recommendation_change_log(created_at);

-- 6. pronto_keyboard_shortcuts
CREATE TABLE IF NOT EXISTS pronto_keyboard_shortcuts (
    id SERIAL PRIMARY KEY,
    combo VARCHAR(50) NOT NULL,
    description VARCHAR(200) NOT NULL,
    category VARCHAR(50) NOT NULL DEFAULT 'General',
    callback_function VARCHAR(100) NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    prevent_default BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT uq_shortcut_combo UNIQUE (combo)
);
CREATE INDEX IF NOT EXISTS ix_shortcut_combo ON pronto_keyboard_shortcuts(combo);
CREATE INDEX IF NOT EXISTS ix_shortcut_enabled ON pronto_keyboard_shortcuts(is_enabled);

-- 7. pronto_discount_codes
CREATE TABLE IF NOT EXISTS pronto_discount_codes (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    discount_type VARCHAR(32) NOT NULL,
    discount_percentage NUMERIC(5,2),
    discount_amount NUMERIC(10,2),
    min_purchase_amount NUMERIC(10,2),
    usage_limit INTEGER,
    times_used INTEGER NOT NULL DEFAULT 0,
    applies_to VARCHAR(32) NOT NULL DEFAULT 'products',
    applicable_tags JSONB,
    applicable_products JSONB,
    valid_from TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    valid_until TIMESTAMP WITHOUT TIME ZONE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT chk_discount_codes_discount_valid CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
    CONSTRAINT chk_discount_codes_amount_positive CHECK (discount_amount >= 0),
    CONSTRAINT chk_discount_codes_usage_limit_positive CHECK (usage_limit >= 0),
    CONSTRAINT chk_discount_codes_times_used_positive CHECK (times_used >= 0)
);
CREATE INDEX IF NOT EXISTS ix_discount_code ON pronto_discount_codes(code);
CREATE INDEX IF NOT EXISTS ix_discount_active_dates ON pronto_discount_codes(is_active, valid_from, valid_until);

-- 8. pronto_secrets
CREATE TABLE IF NOT EXISTS pronto_secrets (
    id SERIAL PRIMARY KEY,
    secret_key VARCHAR(120) NOT NULL UNIQUE,
    secret_value TEXT NOT NULL,
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_secret_key ON pronto_secrets(secret_key);

-- 9. pronto_support_tickets
CREATE TABLE IF NOT EXISTS pronto_support_tickets (
    id SERIAL PRIMARY KEY,
    channel VARCHAR(32) NOT NULL DEFAULT 'client',
    name_encrypted TEXT NOT NULL,
    email_encrypted TEXT NOT NULL,
    description_encrypted TEXT NOT NULL,
    page_url VARCHAR(255),
    user_agent VARCHAR(255),
    status VARCHAR(32) NOT NULL DEFAULT 'open',
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    resolved_at TIMESTAMP WITHOUT TIME ZONE
);
CREATE INDEX IF NOT EXISTS ix_support_ticket_status ON pronto_support_tickets(status);
CREATE INDEX IF NOT EXISTS ix_support_ticket_created_at ON pronto_support_tickets(created_at);
CREATE INDEX IF NOT EXISTS ix_support_ticket_channel ON pronto_support_tickets(channel);

-- 10. pronto_split_bills
CREATE TABLE IF NOT EXISTS pronto_split_bills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES pronto_dining_sessions(id),
    split_type VARCHAR(32) NOT NULL DEFAULT 'by_items',
    status VARCHAR(32) NOT NULL DEFAULT 'active',
    number_of_people INTEGER NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    completed_at TIMESTAMP WITHOUT TIME ZONE
);
CREATE INDEX IF NOT EXISTS ix_split_bill_session ON pronto_split_bills(session_id);
CREATE INDEX IF NOT EXISTS ix_split_bill_status ON pronto_split_bills(status);

-- 11. pronto_split_bill_people
CREATE TABLE IF NOT EXISTS pronto_split_bill_people (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    split_bill_id UUID NOT NULL REFERENCES pronto_split_bills(id),
    person_name VARCHAR(100) NOT NULL,
    person_number INTEGER NOT NULL,
    subtotal NUMERIC(10,2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    tip_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    payment_status VARCHAR(32) NOT NULL DEFAULT 'unpaid',
    customer_email VARCHAR(255),
    payment_method VARCHAR(32),
    payment_reference VARCHAR(128),
    paid_at TIMESTAMP WITHOUT TIME ZONE
);
CREATE INDEX IF NOT EXISTS ix_split_bill_person_split ON pronto_split_bill_people(split_bill_id);

-- 12. pronto_split_bill_assignments
CREATE TABLE IF NOT EXISTS pronto_split_bill_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    split_bill_id UUID NOT NULL REFERENCES pronto_split_bills(id),
    person_id UUID NOT NULL REFERENCES pronto_split_bill_people(id),
    order_item_id UUID NOT NULL REFERENCES pronto_order_items(id),
    quantity_portion NUMERIC(10,2) NOT NULL DEFAULT 1.0,
    amount NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_split_assignment_split ON pronto_split_bill_assignments(split_bill_id);
CREATE INDEX IF NOT EXISTS ix_split_assignment_person ON pronto_split_bill_assignments(person_id);
CREATE INDEX IF NOT EXISTS ix_split_assignment_item ON pronto_split_bill_assignments(order_item_id);

-- 13. pronto_custom_roles
CREATE TABLE IF NOT EXISTS pronto_custom_roles (
    id SERIAL PRIMARY KEY,
    role_code VARCHAR(64) NOT NULL UNIQUE,
    role_name VARCHAR(100) NOT NULL,
    description TEXT,
    color VARCHAR(20),
    icon VARCHAR(50),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT now(),
    created_by UUID REFERENCES pronto_employees(id)
);
CREATE INDEX IF NOT EXISTS ix_custom_role_code ON pronto_custom_roles(role_code);
CREATE INDEX IF NOT EXISTS ix_custom_role_active ON pronto_custom_roles(is_active);

-- 14. pronto_role_permissions
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

-- 15. pronto_employee_preferences
CREATE TABLE IF NOT EXISTS pronto_employee_preferences (
    employee_id UUID NOT NULL REFERENCES pronto_employees(id) ON DELETE CASCADE,
    key VARCHAR(50) NOT NULL,
    value JSONB,
    PRIMARY KEY (employee_id, key)
);

COMMIT;
