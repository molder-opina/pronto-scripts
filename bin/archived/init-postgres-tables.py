#!/usr/bin/env python3
"""
Script para inicializar tablas básicas de PostgreSQL para Pronto.

Este script crea las tablas necesarias para que la aplicación pueda iniciar.
"""

import os
import sys

try:
    import psycopg2
except ImportError:
    print("❌ Error: El paquete 'psycopg2-binary' no está instalado")
    print("   Para instalar: pip install psycopg2-binary")
    sys.exit(1)

print("╔═══════════════════════════════════════════════════╗")
print("║                                                       ║")
print("║   🗄️  INICIALIZANDO TABLAS POSTGRESQL 🗄️   ║")
print("║                                                       ║")
print("╚═════════════════════════════════════════════════════╝")
print("")

# Load configuration from environment
postgres_host = os.getenv("POSTGRES_HOST", "localhost")
postgres_port = os.getenv("POSTGRES_PORT", "5432")
postgres_user = os.getenv("POSTGRES_USER", "pronto")
postgres_password = os.getenv("POSTGRES_PASSWORD", "pronto123")
postgres_db = os.getenv("POSTGRES_DB", "pronto")

print("📊 Configuración:")
print(f"   Host: {postgres_host}:{postgres_port}")
print(f"   Usuario: {postgres_user}")
print(f"   Base de datos: {postgres_db}")
print("")

# Connect to PostgreSQL
print("🔗 Conectando a PostgreSQL...")
try:
    conn = psycopg2.connect(
        host=postgres_host,
        port=postgres_port,
        user=postgres_user,
        password=postgres_password,
        database=postgres_db,
    )
    conn.autocommit = True
    cursor = conn.cursor()
    print("✅ Conectado a PostgreSQL")
except Exception as e:
    print(f"❌ Error al conectar a PostgreSQL: {e}")
    sys.exit(1)

# Create basic tables
print("")
print("📋 Creando tablas básicas...")

# pronto_customers table
cursor.execute(
    """
    CREATE TABLE IF NOT EXISTS pronto_customers (
        id SERIAL PRIMARY KEY,
        email_hash VARCHAR(128) NOT NULL UNIQUE,
        contact_hash VARCHAR(128) NOT NULL,
        name_encrypted TEXT NOT NULL,
        email_encrypted TEXT NOT NULL,
        phone_encrypted TEXT,
        physical_description TEXT,
        avatar VARCHAR(255),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
"""
)
print("   ✓ pronto_customers")

# pronto_employees table
cursor.execute(
    """
    CREATE TABLE IF NOT EXISTS pronto_employees (
        id SERIAL PRIMARY KEY,
        email_hash VARCHAR(128) NOT NULL UNIQUE,
        role VARCHAR(50) NOT NULL,
        is_active BOOLEAN DEFAULT TRUE,
        name_encrypted TEXT NOT NULL,
        email_encrypted TEXT NOT NULL,
        phone_encrypted TEXT,
        avatar VARCHAR(255),
        preferences TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
"""
)
print("   ✓ pronto_employees")

# pronto_dining_sessions table
cursor.execute(
    """
    CREATE TABLE IF NOT EXISTS pronto_dining_sessions (
        id SERIAL PRIMARY KEY,
        table_id INTEGER,
        session_type VARCHAR(50) DEFAULT 'normal',
        customer_id INTEGER REFERENCES pronto_customers(id) ON DELETE SET NULL,
        is_active BOOLEAN DEFAULT TRUE,
        guests INTEGER DEFAULT 1,
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        closed_at TIMESTAMP,
        closed_by INTEGER
    );
"""
)
print("   ✓ pronto_dining_sessions")

# pronto_menu_categories table
cursor.execute(
    """
    CREATE TABLE IF NOT EXISTS pronto_menu_categories (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        display_order INTEGER DEFAULT 0,
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
"""
)
print("   ✓ pronto_menu_categories")

# pronto_menu_items table
cursor.execute(
    """
    CREATE TABLE IF NOT EXISTS pronto_menu_items (
        id SERIAL PRIMARY KEY,
        category_id INTEGER REFERENCES pronto_menu_categories(id) ON DELETE SET NULL,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        price NUMERIC(10,2) NOT NULL DEFAULT 0,
        image_url VARCHAR(500),
        is_available BOOLEAN DEFAULT TRUE,
        display_order INTEGER DEFAULT 0,
        preparation_time_minutes INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
"""
)
print("   ✓ pronto_menu_items")

# pronto_orders table
cursor.execute(
    """
    CREATE TABLE IF NOT EXISTS pronto_orders (
        id SERIAL PRIMARY KEY,
        customer_id INTEGER REFERENCES pronto_customers(id) ON DELETE SET NULL,
        session_id INTEGER REFERENCES pronto_dining_sessions(id) ON DELETE SET NULL,
        workflow_status VARCHAR(32) DEFAULT 'requested',
        payment_status VARCHAR(32) DEFAULT 'unpaid',
        subtotal NUMERIC(10,2) NOT NULL DEFAULT 0,
        tax_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
        tip_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
        total_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
        waiter_id INTEGER REFERENCES pronto_employees(id) ON DELETE SET NULL,
        chef_id INTEGER REFERENCES pronto_employees(id) ON DELETE SET NULL,
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT NOW()
    );
"""
)
print("   ✓ pronto_orders")

# pronto_order_items table
cursor.execute(
    """
    CREATE TABLE IF NOT EXISTS pronto_order_items (
        id SERIAL PRIMARY KEY,
        order_id INTEGER REFERENCES pronto_orders(id) ON DELETE CASCADE,
        menu_item_id INTEGER REFERENCES pronto_menu_items(id) ON DELETE SET NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price NUMERIC(10,2) NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
"""
)
print("   ✓ pronto_order_items")

# pronto_business_config table
cursor.execute(
    """
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
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_by INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
"""
)
print("   ✓ pronto_business_config")

# pronto_business_info table
cursor.execute(
    """
    CREATE TABLE IF NOT EXISTS pronto_business_info (
        id SERIAL PRIMARY KEY,
        restaurant_name VARCHAR(255) NOT NULL,
        slug VARCHAR(255) NOT NULL UNIQUE,
        description TEXT,
        logo_url VARCHAR(500),
        timezone VARCHAR(100),
        currency VARCHAR(10) DEFAULT 'MXN',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
"""
)
print("   ✓ pronto_business_info")

# Create indexes
print("")
print("📋 Creando índices...")

# pronto_customers indexes
cursor.execute("CREATE INDEX IF NOT EXISTS ix_customer_email_hash ON pronto_customers(email_hash);")
cursor.execute("CREATE INDEX IF NOT EXISTS ix_customer_created_at ON pronto_customers(created_at);")

# pronto_orders indexes
cursor.execute(
    "CREATE INDEX IF NOT EXISTS ix_order_workflow_status ON pronto_orders(workflow_status);"
)
cursor.execute("CREATE INDEX IF NOT EXISTS ix_order_customer_id ON pronto_orders(customer_id);")
cursor.execute("CREATE INDEX IF NOT EXISTS ix_order_session_id ON pronto_orders(session_id);")
cursor.execute("CREATE INDEX IF NOT EXISTS ix_order_created_at ON pronto_orders(created_at);")

# pronto_order_items indexes
cursor.execute("CREATE INDEX IF NOT EXISTS ix_order_item_order_id ON pronto_order_items(order_id);")
cursor.execute(
    "CREATE INDEX IF NOT EXISTS ix_order_item_menu_item_id ON pronto_order_items(menu_item_id);"
)

# pronto_business_config indexes
cursor.execute(
    "CREATE INDEX IF NOT EXISTS ix_business_config_key ON pronto_business_config(config_key);"
)

print("   ✓ Índices creados")

# Insert default business config
print("")
print("📊 Creando configuración por defecto...")

# First, create a business info
cursor.execute(
    """
    INSERT INTO pronto_business_info (restaurant_name, slug, description)
    VALUES ('Cafetería de Prueba', 'cafeteria-test', 'Configuración por defecto para desarrollo local')
    ON CONFLICT (slug) DO NOTHING;
"""
)

# Then create default business config
default_configs = [
    ("restaurant_name", "Cafetería de Prueba"),
    ("tax_rate", "0.16"),
    ("currency", "MXN"),
    ("time_zone", "America/Mexico_City"),
    ("session_timeout_minutes", "30"),
    ("order_preparation_time_minutes", "15"),
    ("enable_notifications", "true"),
    ("customer_session_cookie_name", "pronto_customer_session"),
    ("employee_session_cookie_name", "pronto_employee_session"),
    ("restaurant_email", "noreply@cafeteria.test"),
    ("restaurant_phone", "+5255555555"),
    ("restaurant_address", "Av. Principal 123"),
    ("business_hours_start", "08:00"),
    ("business_hours_end", "22:00"),
    ("logo_url", "/assets/cafeteria-test/logo.png"),
    ("primary_color", "#FF5722"),
    ("secondary_color", "#FFC107"),
    ("table_count", "20"),
    ("enable_orders", "true"),
    ("enable_kitchen_display", "true"),
    ("enable_payments", "true"),
]

for config_key, config_value in default_configs:
    display_name = config_key.replace("_", " ").title()
    description = f"Default config for {display_name.lower()}"

    cursor.execute(
        """
        INSERT INTO pronto_business_config
        (config_key, config_value, value_type, category, display_name, description)
        VALUES (%s, %s, 'string', 'general', %s, %s)
        ON CONFLICT (config_key) DO NOTHING;
    """,
        (config_key, config_value, display_name, description),
    )

print(f"   ✓ {len(default_configs)} configuraciones por defecto creadas")

# Create sample menu
print("")
print("📊 Creando menú de ejemplo...")

# Create a category if it doesn't exist
cursor.execute(
    """
    INSERT INTO pronto_menu_categories (name, description, display_order)
    VALUES ('Bebidas', 'Bebidas frías y calientes', 1)
    ON CONFLICT DO NOTHING;
"""
)

# Get the category ID
cursor.execute("SELECT id FROM pronto_menu_categories WHERE name = 'Bebidas' LIMIT 1;")
category_row = cursor.fetchone()
category_id = category_row[0] if category_row else None

if category_id:
    # Create sample menu items
    sample_items = [
        ("Café Americano", "Café recién preparado", 25.00, 1),
        ("Café Espresso", "Café espresso italiano", 35.00, 2),
        ("Cappuccino", "Cappuccino con leche espumada", 40.00, 3),
        ("Chocolate Caliente", "Chocolate caliente con malvaviscos", 35.00, 4),
        ("Té Chai", "Té chai caliente", 30.00, 5),
        ("Agua Mineral", "Botella de agua mineral", 15.00, 6),
    ]

    for name, description, price, display_order in sample_items:
        cursor.execute(
            """
            INSERT INTO pronto_menu_items (category_id, name, description, price, display_order)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT DO NOTHING;
        """,
            (category_id, name, description, price, display_order),
        )

    print(f"   ✓ {len(sample_items)} items de menú creados")

# Verify tables
print("")
print("📋 Verificando tablas creadas...")
cursor.execute(
    """
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
    ORDER BY table_name;
"""
)

tables = [row[0] for row in cursor.fetchall()]
print(f"✅ {len(tables)} tablas creadas:")
for table in sorted(tables):
    print(f"   - {table}")

# Close connection
cursor.close()
conn.close()

print("")
print("╔═══════════════════════════════════════════════════╗")
print("║                                                       ║")
print("║   ✅ INICIALIZACIÓN COMPLETADA                     ║")
print("║                                                       ║")
print("╚═════════════════════════════════════════════════════╝")
print("")
print("🚀 Para iniciar el proyecto en modo debug:")
print("   bash bin/up-debug.sh")
print("")
