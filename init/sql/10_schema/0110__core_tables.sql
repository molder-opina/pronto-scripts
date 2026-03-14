CREATE TABLE IF NOT EXISTS pronto_customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  anon_id VARCHAR(36) UNIQUE,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100),
  email_hash VARCHAR(128) UNIQUE,
  contact_hash VARCHAR(128),
  auth_hash VARCHAR(255),
  password_hash VARCHAR(255),
  loyalty_points INTEGER DEFAULT 0,
  total_spent NUMERIC(12,2) DEFAULT 0.00,
  visit_count INTEGER DEFAULT 0,
  notes TEXT,
  preferences JSONB,
  name_encrypted TEXT,
  email_encrypted TEXT,
  phone_encrypted TEXT,
  physical_description TEXT,
  avatar VARCHAR(255),
  kind VARCHAR(20) DEFAULT 'customer',
  kiosk_location VARCHAR(50),
  name_search TEXT,
  email_normalized TEXT,
  phone_e164 VARCHAR(50),
  tax_id VARCHAR(32),
  tax_name VARCHAR(255),
  tax_address TEXT,
  tax_email VARCHAR(255),
  tax_regime VARCHAR(100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_employees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_code VARCHAR(50) NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100),
  email VARCHAR(255),
  phone VARCHAR(20),
  pin VARCHAR(10),
  role VARCHAR(50) DEFAULT 'staff',
  department VARCHAR(100),
  hire_date DATE,
  status VARCHAR(20) DEFAULT 'active',
  permissions JSONB,
  clocked_in BOOLEAN DEFAULT FALSE,
  current_session_id UUID,
  last_clock_in TIMESTAMP WITH TIME ZONE,
  total_hours NUMERIC(10,2) DEFAULT 0.00,
  auth_hash VARCHAR(255),
  email_hash VARCHAR(128),
  email_encrypted TEXT,
  name_encrypted TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  allow_scopes JSONB,
  additional_roles TEXT,
  signed_in_at TIMESTAMP WITHOUT TIME ZONE,
  last_activity_at TIMESTAMP WITHOUT TIME ZONE,
  preferences JSONB,
  phone_encrypted TEXT,
  reset_token VARCHAR(100),
  reset_token_expires_at TIMESTAMP WITHOUT TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_dining_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_id UUID,
  customer_id UUID,
  employee_id UUID,
  opened_at TIMESTAMPTZ DEFAULT now(),
  closed_at TIMESTAMPTZ,
  party_size INTEGER DEFAULT 2,
  status VARCHAR(50) DEFAULT 'active',
  subtotal NUMERIC(12,2) DEFAULT 0.00,
  tax_amount NUMERIC(12,2) DEFAULT 0.00,
  tip_amount NUMERIC(12,2) DEFAULT 0.00,
  total_amount NUMERIC(12,2) DEFAULT 0.00,
  payment_status VARCHAR(20) DEFAULT 'pending',
  payment_method VARCHAR(50),
  notes TEXT,
  anon_id VARCHAR(36),
  total_paid NUMERIC(12,2) DEFAULT 0.00,
  table_number VARCHAR(32),
  expires_at TIMESTAMPTZ,
  payment_reference VARCHAR(128),
  payment_confirmed_at TIMESTAMPTZ,
  tip_requested_at TIMESTAMPTZ,
  tip_confirmed_at TIMESTAMPTZ,
  check_requested_at TIMESTAMPTZ,
  feedback_requested_at TIMESTAMPTZ,
  feedback_completed_at TIMESTAMPTZ,
  email_encrypted TEXT,
  email_hash VARCHAR(128),
  feedback_rating INTEGER,
  feedback_comment TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_menu_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL UNIQUE,
  slug VARCHAR(120) NOT NULL UNIQUE,
  revision INTEGER NOT NULL DEFAULT 1,
  description TEXT,
  image_url TEXT,
  parent_category_id UUID REFERENCES pronto_menu_categories(id),
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_menu_subcategories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_category_id UUID NOT NULL REFERENCES pronto_menu_categories(id),
    name VARCHAR(120) NOT NULL,
    slug VARCHAR(120) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    revision INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_menu_subcategories_category_slug UNIQUE (menu_category_id, slug)
);

CREATE TABLE IF NOT EXISTS pronto_menu_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID REFERENCES pronto_menu_categories(id),
  menu_category_id UUID REFERENCES pronto_menu_categories(id),
  menu_subcategory_id UUID REFERENCES pronto_menu_subcategories(id),
  item_kind VARCHAR(16) NOT NULL DEFAULT 'product',
  name VARCHAR(255) NOT NULL,
  description TEXT,
  price NUMERIC(10, 2) NOT NULL DEFAULT 0,
  image_path VARCHAR(255),
  image_url TEXT,
  is_available BOOLEAN DEFAULT TRUE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_featured BOOLEAN DEFAULT FALSE,
  display_order INTEGER DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  preparation_time_minutes INTEGER DEFAULT 15,
  calories INTEGER,
  allergens TEXT[],
  is_afternoon_recommended BOOLEAN NOT NULL DEFAULT FALSE,
  is_night_recommended BOOLEAN NOT NULL DEFAULT FALSE,
  track_inventory BOOLEAN NOT NULL DEFAULT FALSE,
  stock_quantity INTEGER,
  low_stock_threshold INTEGER,
  is_quick_serve BOOLEAN NOT NULL DEFAULT FALSE,
  is_breakfast_recommended BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT chk_menu_items_item_kind CHECK (item_kind IN ('product', 'combo', 'package'))
);

CREATE TABLE IF NOT EXISTS pronto_product_labels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(120) NOT NULL,
    slug VARCHAR(120) NOT NULL UNIQUE,
    label_type VARCHAR(24) NOT NULL DEFAULT 'badge',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_quick_filter BOOLEAN NOT NULL DEFAULT FALSE,
    quick_filter_sort_order INTEGER NOT NULL DEFAULT 0,
    revision INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_product_labels_type CHECK (label_type IN ('promo', 'badge', 'collection'))
);

CREATE TABLE IF NOT EXISTS pronto_product_label_map (
    product_id UUID NOT NULL REFERENCES pronto_menu_items(id),
    label_id UUID NOT NULL REFERENCES pronto_product_labels(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (product_id, label_id)
);

CREATE TABLE IF NOT EXISTS pronto_menu_home_modules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(160) NOT NULL,
    slug VARCHAR(160) NOT NULL UNIQUE,
    module_type VARCHAR(32) NOT NULL,
    source_type VARCHAR(32) NOT NULL,
    source_ref_id UUID,
    source_item_kind VARCHAR(16),
    placement VARCHAR(32) NOT NULL DEFAULT 'home_client',
    sort_order INTEGER NOT NULL DEFAULT 0,
    max_items INTEGER NOT NULL DEFAULT 8,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    show_title BOOLEAN NOT NULL DEFAULT TRUE,
    show_view_all BOOLEAN NOT NULL DEFAULT FALSE,
    revision INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_menu_home_module_type CHECK (module_type IN ('hero', 'carousel', 'grid', 'chips', 'category_section')),
    CONSTRAINT chk_menu_home_source_type CHECK (source_type IN ('label', 'category', 'subcategory', 'item_kind', 'manual')),
    CONSTRAINT chk_menu_home_item_kind CHECK (source_item_kind IS NULL OR source_item_kind IN ('product', 'combo', 'package')),
    CONSTRAINT chk_menu_home_source_ref_rules CHECK (
        (source_type = 'manual' AND source_ref_id IS NULL)
        OR (source_type = 'item_kind' AND source_ref_id IS NULL AND source_item_kind IS NOT NULL)
        OR (source_type IN ('label', 'category', 'subcategory') AND source_ref_id IS NOT NULL)
    )
);

CREATE TABLE IF NOT EXISTS pronto_menu_home_module_products (
    module_id UUID NOT NULL REFERENCES pronto_menu_home_modules(id),
    product_id UUID NOT NULL REFERENCES pronto_menu_items(id),
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (module_id, product_id)
);

CREATE TABLE IF NOT EXISTS pronto_menu_home_publication_state (
    placement VARCHAR(32) PRIMARY KEY,
    draft_version INTEGER NOT NULL DEFAULT 1,
    published_version INTEGER NOT NULL DEFAULT 1,
    snapshot_revision VARCHAR(64) NOT NULL DEFAULT 'baseline-v1',
    publish_lock BOOLEAN NOT NULL DEFAULT FALSE,
    publish_status VARCHAR(16) NOT NULL DEFAULT 'idle',
    last_publish_at TIMESTAMPTZ,
    last_publish_error TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_menu_home_publish_status CHECK (publish_status IN ('idle', 'running', 'failed', 'succeeded'))
);

CREATE TABLE IF NOT EXISTS pronto_menu_home_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    placement VARCHAR(32) NOT NULL,
    version INTEGER NOT NULL,
    revision VARCHAR(64) NOT NULL,
    payload JSONB NOT NULL,
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_menu_home_snapshot_version UNIQUE (placement, version),
    CONSTRAINT uq_menu_home_snapshot_revision UNIQUE (placement, revision)
);

CREATE TABLE IF NOT EXISTS pronto_modifier_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  selection_type VARCHAR(50) DEFAULT 'single',
  min_select INTEGER DEFAULT 0,
  max_select INTEGER DEFAULT 1,
  is_required BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_modifiers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES pronto_modifier_groups(id),
  name VARCHAR(255) NOT NULL,
  price_adjustment NUMERIC(10, 2) DEFAULT 0,
  image_path VARCHAR(500),
  is_available BOOLEAN DEFAULT TRUE,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_menu_package_components (
  package_item_id UUID NOT NULL REFERENCES pronto_menu_items(id) ON DELETE CASCADE,
  component_item_id UUID NOT NULL REFERENCES pronto_menu_items(id) ON DELETE RESTRICT,
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  min_selection INTEGER NOT NULL DEFAULT 1,
  max_selection INTEGER NOT NULL DEFAULT 1,
  is_required BOOLEAN NOT NULL DEFAULT TRUE,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (package_item_id, component_item_id),
  CONSTRAINT chk_package_components_selection_bounds
    CHECK (min_selection >= 0 AND max_selection >= 0 AND min_selection <= max_selection)
);

CREATE INDEX IF NOT EXISTS idx_package_components_package
  ON pronto_menu_package_components(package_item_id, display_order);
CREATE INDEX IF NOT EXISTS idx_package_components_component
  ON pronto_menu_package_components(component_item_id);

CREATE TABLE IF NOT EXISTS pronto_areas (
  id SERIAL PRIMARY KEY,
  name VARCHAR(120) NOT NULL UNIQUE,
  description TEXT,
  prefix VARCHAR(16) UNIQUE,
  color VARCHAR(32) DEFAULT '#ff6b35',
  background_image TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pronto_tables (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_number VARCHAR(32) NOT NULL UNIQUE,
  area_id INTEGER NOT NULL REFERENCES pronto_areas(id),
  capacity INTEGER DEFAULT 4,
  qr_code VARCHAR(100),
  status VARCHAR(20) DEFAULT 'available',
  position_x INTEGER,
  position_y INTEGER,
  shape VARCHAR(32) DEFAULT 'square',
  notes TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE SEQUENCE IF NOT EXISTS pronto_orders_order_number_seq
  AS BIGINT
  START WITH 1
  INCREMENT BY 1
  MINVALUE 1
  MAXVALUE 9999999999
  CACHE 1;

CREATE TABLE IF NOT EXISTS pronto_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number BIGINT NOT NULL DEFAULT nextval('pronto_orders_order_number_seq')
    CHECK (order_number BETWEEN 1 AND 9999999999),
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

CREATE TABLE IF NOT EXISTS pronto_carts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_ref UUID NOT NULL,
  customer_id UUID REFERENCES pronto_customers(id),
  dining_session_id UUID REFERENCES pronto_dining_sessions(id),
  table_id UUID REFERENCES pronto_tables(id),
  table_number VARCHAR(32),
  status VARCHAR(16) NOT NULL DEFAULT 'active',
  notes TEXT,
  submitted_order_id UUID REFERENCES pronto_orders(id),
  submitted_at TIMESTAMPTZ,
  last_submit_meta JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_pronto_carts_status
    CHECK (status IN ('active', 'submitted', 'abandoned'))
);

CREATE TABLE IF NOT EXISTS pronto_cart_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cart_id UUID NOT NULL REFERENCES pronto_carts(id) ON DELETE CASCADE,
  menu_item_id UUID NOT NULL REFERENCES pronto_menu_items(id),
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  special_instructions TEXT,
  unit_price_snapshot NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  modifiers_snapshot JSONB NOT NULL DEFAULT '[]'::jsonb,
  modifier_none_groups JSONB NOT NULL DEFAULT '[]'::jsonb,
  package_components_snapshot JSONB NOT NULL DEFAULT '[]'::jsonb,
  item_signature VARCHAR(128) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
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
CREATE UNIQUE INDEX IF NOT EXISTS ix_orders_order_number ON pronto_orders(order_number);
CREATE INDEX IF NOT EXISTS ix_order_items_order_id ON pronto_order_items(order_id);
CREATE INDEX IF NOT EXISTS ix_carts_customer_ref ON pronto_carts(customer_ref);
CREATE INDEX IF NOT EXISTS ix_carts_status ON pronto_carts(status);
CREATE INDEX IF NOT EXISTS ix_carts_created_at ON pronto_carts(created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS ix_carts_active_customer_ref
  ON pronto_carts(customer_ref) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS ix_cart_items_cart_id ON pronto_cart_items(cart_id);
CREATE UNIQUE INDEX IF NOT EXISTS ix_cart_items_signature
  ON pronto_cart_items(cart_id, item_signature);
CREATE UNIQUE INDEX IF NOT EXISTS ix_table_qr_code ON pronto_tables(qr_code);
