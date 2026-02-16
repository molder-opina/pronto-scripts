CREATE TABLE IF NOT EXISTS pronto_customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  anon_id VARCHAR(36) UNIQUE,
  email_hash VARCHAR(128) UNIQUE,
  contact_hash VARCHAR(128),
  auth_hash VARCHAR(128),
  password_hash VARCHAR(255),
  name_encrypted TEXT,
  email_encrypted TEXT,
  phone_encrypted TEXT,
  physical_description TEXT,
  avatar VARCHAR(255),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role VARCHAR(50) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  email_hash VARCHAR(128) UNIQUE,
  auth_hash VARCHAR(128),
  email_encrypted TEXT,
  name_encrypted TEXT,
  phone_encrypted TEXT,
  avatar VARCHAR(255),
  preferences JSONB,
  allow_scopes JSONB,
  additional_roles TEXT,
  signed_in_at TIMESTAMPTZ,
  last_activity_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_dining_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_id UUID,
  table_number VARCHAR(32),
  session_type VARCHAR(50) DEFAULT 'normal',
  customer_id UUID REFERENCES pronto_customers(id),
  is_active BOOLEAN DEFAULT TRUE,
  status VARCHAR(20) DEFAULT 'open',
  guests INTEGER DEFAULT 1,
  notes TEXT,
  start_time TIMESTAMPTZ DEFAULT now(),
  end_time TIMESTAMPTZ,
  total NUMERIC(12, 2) DEFAULT 0.00,
  total_paid NUMERIC(12, 2) DEFAULT 0.00,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_menu_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  description TEXT,
  display_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_menu_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID REFERENCES pronto_menu_categories(id),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  price NUMERIC(10, 2) NOT NULL DEFAULT 0,
  image_path VARCHAR(500),
  image_url VARCHAR(500),
  is_available BOOLEAN DEFAULT TRUE,
  display_order INTEGER DEFAULT 0,
  preparation_time_minutes INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_modifier_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  selection_type VARCHAR(50) DEFAULT 'single',
  min_select INTEGER DEFAULT 0,
  max_select INTEGER DEFAULT 1,
  is_required BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_modifiers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES pronto_modifier_groups(id),
  name VARCHAR(255) NOT NULL,
  price_adjustment NUMERIC(10, 2) DEFAULT 0,
  is_available BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_areas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(120) NOT NULL UNIQUE,
  description TEXT,
  prefix VARCHAR(16),
  color VARCHAR(32),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_tables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_number VARCHAR(32) NOT NULL UNIQUE,
  area_id UUID REFERENCES pronto_areas(id),
  capacity INTEGER DEFAULT 4,
  qr_code VARCHAR(100),
  status VARCHAR(20) DEFAULT 'available',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES pronto_customers(id),
  session_id UUID REFERENCES pronto_dining_sessions(id),
  anonymous_client_id VARCHAR(36),
  workflow_status VARCHAR(32) NOT NULL DEFAULT 'requested',
  payment_status VARCHAR(32) NOT NULL DEFAULT 'unpaid',
  payment_method VARCHAR(32),
  payment_reference VARCHAR(128),
  payment_meta JSONB,
  notes TEXT,
  subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  tip_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
  waiter_id UUID,
  chef_id UUID,
  served_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES pronto_orders(id),
  menu_item_id UUID REFERENCES pronto_menu_items(id),
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price NUMERIC(10, 2) NOT NULL DEFAULT 0,
  notes TEXT,
  served_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_business_config (
  id SERIAL PRIMARY KEY,
  config_key VARCHAR(255) NOT NULL UNIQUE,
  config_value TEXT,
  value_type VARCHAR(50) DEFAULT 'string',
  category VARCHAR(100) DEFAULT 'general',
  display_name VARCHAR(255),
  description TEXT,
  min_value VARCHAR(255),
  max_value VARCHAR(255),
  unit VARCHAR(50),
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_business_schedule (
  day_of_week INTEGER PRIMARY KEY,
  is_open BOOLEAN NOT NULL DEFAULT TRUE,
  open_time VARCHAR(5) NOT NULL DEFAULT '00:00',
  close_time VARCHAR(5) NOT NULL DEFAULT '23:59',
  notes TEXT
);

CREATE INDEX IF NOT EXISTS ix_customer_email_hash ON pronto_customers(email_hash);
CREATE INDEX IF NOT EXISTS ix_customer_anon_id ON pronto_customers(anon_id);
CREATE INDEX IF NOT EXISTS ix_employee_email_hash ON pronto_employees(email_hash);
CREATE INDEX IF NOT EXISTS ix_employee_role_active ON pronto_employees(role, status);
CREATE INDEX IF NOT EXISTS ix_orders_session_id ON pronto_orders(session_id);
CREATE INDEX IF NOT EXISTS ix_orders_workflow_status ON pronto_orders(workflow_status);
CREATE INDEX IF NOT EXISTS ix_order_items_order_id ON pronto_order_items(order_id);
CREATE UNIQUE INDEX IF NOT EXISTS ix_table_qr_code ON pronto_tables(qr_code);
