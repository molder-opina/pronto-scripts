DROP TABLE IF EXISTS pronto_order_items CASCADE;
DROP TABLE IF EXISTS pronto_orders CASCADE;
DROP TABLE IF EXISTS pronto_kitchen_orders CASCADE;
DROP TABLE IF EXISTS pronto_dining_sessions CASCADE;
DROP TABLE IF EXISTS pronto_table_log CASCADE;
DROP TABLE IF EXISTS pronto_employees CASCADE;
DROP TABLE IF EXISTS pronto_customers CASCADE;
DROP TABLE IF EXISTS pronto_modifiers CASCADE;
DROP TABLE IF EXISTS pronto_modifier_groups CASCADE;
DROP TABLE IF EXISTS pronto_menu_items CASCADE;
DROP TABLE IF EXISTS pronto_menu_categories CASCADE;
DROP TABLE IF EXISTS pronto_tables CASCADE;
DROP TABLE IF EXISTS pronto_areas CASCADE;
DROP TABLE IF EXISTS pronto_day_periods CASCADE;
DROP TABLE IF EXISTS pronto_business_config CASCADE;

CREATE TABLE pronto_business_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_key VARCHAR(100) NOT NULL UNIQUE,
    config_value TEXT,
    value_type VARCHAR(20) DEFAULT 'string',
    category VARCHAR(50),
    display_name VARCHAR(100),
    description TEXT,
    min_value DECIMAL(10,2),
    max_value DECIMAL(10,2),
    unit VARCHAR(50),
    options JSONB,
    is_editable BOOLEAN DEFAULT true,
    is_required BOOLEAN DEFAULT false,
    updated_at TIMESTAMP WITH TIME ZONE,
    updated_by UUID
);

CREATE TABLE pronto_areas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE pronto_tables (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_number VARCHAR(20) NOT NULL,
    area_id UUID REFERENCES pronto_areas(id),
    capacity INTEGER DEFAULT 4,
    status VARCHAR(20) DEFAULT 'available',
    current_session_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE pronto_day_periods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE pronto_menu_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    image_url TEXT,
    parent_category_id UUID REFERENCES pronto_menu_categories(id),
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE pronto_menu_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    category_id UUID REFERENCES pronto_menu_categories(id),
    image_url TEXT,
    preparation_time_minutes INTEGER DEFAULT 15,
    is_available BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    calories INTEGER,
    allergens TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE pronto_modifier_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    menu_item_id UUID REFERENCES pronto_menu_items(id),
    min_selections INTEGER DEFAULT 0,
    max_selections INTEGER DEFAULT 1,
    is_required BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE pronto_modifiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    price_adjustment DECIMAL(10,2) DEFAULT 0.00,
    group_id UUID REFERENCES pronto_modifier_groups(id),
    is_default BOOLEAN DEFAULT false,
    is_available BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE pronto_customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100),
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    loyalty_points INTEGER DEFAULT 0,
    total_spent DECIMAL(12,2) DEFAULT 0.00,
    visit_count INTEGER DEFAULT 0,
    notes TEXT,
    preferences JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE pronto_employees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_code VARCHAR(50) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100),
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    pin VARCHAR(10),
    role VARCHAR(50) DEFAULT 'staff',
    department VARCHAR(100),
    hire_date DATE,
    status VARCHAR(20) DEFAULT 'active',
    permissions JSONB,
    clocked_in BOOLEAN DEFAULT false,
    current_session_id UUID,
    last_clock_in TIMESTAMP WITH TIME ZONE,
    total_hours DECIMAL(10,2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE pronto_dining_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_id UUID REFERENCES pronto_tables(id),
    customer_id UUID REFERENCES pronto_customers(id),
    employee_id UUID REFERENCES pronto_employees(id),
    start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    end_time TIMESTAMP WITH TIME ZONE,
    party_size INTEGER DEFAULT 2,
    status VARCHAR(20) DEFAULT 'active',
    subtotal DECIMAL(12,2) DEFAULT 0.00,
    tax_amount DECIMAL(12,2) DEFAULT 0.00,
    tip_amount DECIMAL(12,2) DEFAULT 0.00,
    total DECIMAL(12,2) DEFAULT 0.00,
    payment_status VARCHAR(20) DEFAULT 'pending',
    payment_method VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE pronto_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES pronto_dining_sessions(id),
    customer_id UUID REFERENCES pronto_customers(id),
    employee_id UUID REFERENCES pronto_employees(id),
    order_number VARCHAR(50),
    order_type VARCHAR(20) DEFAULT 'dine-in',
    status VARCHAR(20) DEFAULT 'pending',
    subtotal DECIMAL(12,2) DEFAULT 0.00,
    tax_amount DECIMAL(12,2) DEFAULT 0.00,
    discount_amount DECIMAL(12,2) DEFAULT 0.00,
    total DECIMAL(12,2) DEFAULT 0.00,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE pronto_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES pronto_orders(id),
    menu_item_id UUID REFERENCES pronto_menu_items(id),
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    modifiers JSONB,
    special_instructions TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    served_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE pronto_kitchen_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES pronto_orders(id),
    order_item_ids UUID[],
    station VARCHAR(50),
    priority INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'pending',
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE pronto_table_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_id UUID REFERENCES pronto_tables(id),
    session_id UUID REFERENCES pronto_dining_sessions(id),
    action VARCHAR(50) NOT NULL,
    previous_value TEXT,
    new_value TEXT,
    employee_id UUID REFERENCES pronto_employees(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_pronto_menu_items_category ON pronto_menu_items(category_id);
CREATE INDEX idx_pronto_menu_items_available ON pronto_menu_items(is_available);
CREATE INDEX idx_pronto_orders_session ON pronto_orders(session_id);
CREATE INDEX idx_pronto_orders_status ON pronto_orders(status);
CREATE INDEX idx_pronto_dining_sessions_table ON pronto_dining_sessions(table_id);
CREATE INDEX idx_pronto_dining_sessions_status ON pronto_dining_sessions(status);
CREATE INDEX idx_pronto_customers_email ON pronto_customers(email);
CREATE INDEX idx_pronto_employees_code ON pronto_employees(employee_code);
CREATE INDEX idx_pronto_kitchen_orders_status ON pronto_kitchen_orders(status);

INSERT INTO pronto_areas (name, sort_order) VALUES
('Main Floor', 1),
('Patio', 2),
('Bar', 3),
('Private Room', 4);

INSERT INTO pronto_menu_categories (name, sort_order) VALUES
('Appetizers', 1),
('Main Courses', 2),
('Desserts', 3),
('Beverages', 4);

INSERT INTO pronto_day_periods (name, start_time, end_time, sort_order) VALUES
('Breakfast', '06:00', '11:00', 1),
('Lunch', '11:00', '15:00', 2),
('Dinner', '15:00', '22:00', 3),
('Late Night', '22:00', '02:00', 4);
