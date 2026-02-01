#!/usr/bin/env python3
"""
Script para crear datos de prueba en PostgreSQL local.

Este script:
1. Conecta a PostgreSQL local
2. Crea empleados de prueba con contraseñas simples (JWT-compatible)
3. Crea clientes de prueba
4. Crea menú de ejemplo
5. Crea configuraciones necesarias
"""

import os
import sys

# Add project to path for shared imports
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(project_root, "build"))

try:
    import psycopg2
except ImportError:
    print("❌ Error: El paquete 'psycopg2-binary' no está instalado")
    print("   Para instalar: pip install psycopg2-binary")
    sys.exit(1)

try:
    from shared.security import hash_credentials, hash_identifier
except ImportError:
    print("❌ Error: No se puede importar shared.security")
    print("   Asegúrate de que el directorio src/shared existe")
    sys.exit(1)


print("╔═══════════════════════════════════════════════════════════╗")
print("║                                                       ║")
print("║   🎲 CREANDO DATOS DE PRUEBA POSTGRESQL 🎲        ║")
print("║                                                       ║")
print("╚═══════════════════════════════╗")
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

# Create tables
print("")
print("📋 Creando tablas...")

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
        auth_hash VARCHAR(128) NOT NULL DEFAULT '',
        role VARCHAR(50) NOT NULL,
        is_active BOOLEAN DEFAULT TRUE,
        name_encrypted TEXT NOT NULL,
        email_encrypted TEXT NOT NULL,
        phone_encrypted TEXT,
        avatar VARCHAR(255),
        preferences TEXT,
        allow_scopes TEXT,
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
        workflow_status VARCHAR(32) NOT NULL DEFAULT 'requested',
        payment_status VARCHAR(32) NOT NULL DEFAULT 'unpaid',
        payment_method VARCHAR(32),
        payment_reference VARCHAR(128),
        notes TEXT,
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
cursor.execute("CREATE INDEX IF NOT EXISTS ix_customer_email_hash ON pronto_customers(email_hash);")
cursor.execute("CREATE INDEX IF NOT EXISTS ix_customer_created_at ON pronto_customers(created_at);")
cursor.execute(
    "CREATE INDEX IF NOT EXISTS ix_order_workflow_status ON pronto_orders(workflow_status);"
)
cursor.execute("CREATE INDEX IF NOT EXISTS ix_order_customer_id ON pronto_orders(customer_id);")
cursor.execute("CREATE INDEX IF NOT EXISTS ix_order_session_id ON pronto_orders(session_id);")
cursor.execute("CREATE INDEX IF NOT EXISTS ix_order_created_at ON pronto_orders(created_at);")
cursor.execute("CREATE INDEX IF NOT EXISTS ix_order_item_order_id ON pronto_order_items(order_id);")
cursor.execute(
    "CREATE INDEX IF NOT EXISTS ix_order_item_menu_item_id ON pronto_order_items(menu_item_id);"
)
cursor.execute(
    "CREATE INDEX IF NOT EXISTS ix_business_config_key ON pronto_business_config(config_key);"
)

print("   ✓ Índices creados")

# Create sample menu
print("")
print("📊 Creando menú de ejemplo...")

# Create beverage category
cursor.execute(
    """
    INSERT INTO pronto_menu_categories (name, description, display_order)
    VALUES ('Bebidas', 'Bebidas frías y calientes', 1)
    ON CONFLICT DO NOTHING;
"""
)
print("   ✓ Categoría 'Bebidas' creada")

# Get category ID
cursor.execute("SELECT id FROM pronto_menu_categories WHERE name = 'Bebidas' LIMIT 1;")
category_row = cursor.fetchone()
category_id = category_row[0] if category_row else None

# Create sample menu items
if category_id:
    sample_items = [
        ("Café Americano", "Café recién preparado", "25.00", 1),
        ("Café Espresso", "Café espresso italiano", "35.00", 2),
        ("Cappuccino", "Cappuccino con leche espumada", "40.00", 3),
        ("Chocolate Caliente", "Chocolate caliente con malvaviscos", "35.00", 4),
        ("Té Chai", "Té chai caliente", "30.00", 5),
        ("Agua Mineral", "Botella de agua mineral", "15.00", 6),
    ]

    for name, description, price, _display_order in sample_items:
        cursor.execute(
            """
            INSERT INTO pronto_menu_items
            (category_id, name, description, price, is_available)
            VALUES (%s, %s, %s, %s, true);
        """,
            (category_id, name, description, price),
        )

print("   ✓ " + str(len(sample_items)) + " items de menú creados")

# Create test employees
print("")
print("👥 Creando empleados de prueba...")

employees = [
    {
        "email": "admin@cafeteria.test",
        "role": "admin",
        "name": "Administrador",
        "phone": "",
        "is_active": True,
        "email_encrypted": "admin@cafeteria.test",
        "name_encrypted": "Administrador",
        "phone_encrypted": "",
        "allow_scopes": '["admin"]',
    },
    {
        "email": "carlos.chef@cafeteria.test",
        "role": "chef",
        "name": "Carlos Chef",
        "phone": "",
        "is_active": True,
        "email_encrypted": "carlos.chef@cafeteria.test",
        "name_encrypted": "Carlos Chef",
        "phone_encrypted": "",
        "allow_scopes": '["chef"]',
    },
    {
        "email": "juan.mesero@cafeteria.test",
        "role": "waiter",
        "name": "Juan Mesero",
        "phone": "",
        "is_active": True,
        "email_encrypted": "juan.mesero@cafeteria.test",
        "name_encrypted": "Juan Mesero",
        "phone_encrypted": "",
        "allow_scopes": '["waiter"]',
    },
    {
        "email": "laura.cajera@cafeteria.test",
        "role": "cashier",
        "name": "Laura Cajera",
        "phone": "",
        "is_active": True,
        "email_encrypted": "laura.cajera@cafeteria.test",
        "name_encrypted": "Laura Cajera",
        "phone_encrypted": "",
        "allow_scopes": '["cashier"]',
    },
]

for emp in employees:
    email = emp["email"]
    email_hash = hash_identifier(email)
    auth_hash = hash_credentials(email, "ChangeMe!123")
    allow_scopes = emp.get("allow_scopes", "[]")

    cursor.execute(
        """
        INSERT INTO pronto_employees
            (email_hash, auth_hash, role, is_active, name_encrypted, email_encrypted, phone_encrypted, preferences, allow_scopes)
            VALUES (%s, %s, %s, true, %s, %s, %s, %s, %s)
            ON CONFLICT (email_hash) DO UPDATE SET
                auth_hash = EXCLUDED.auth_hash,
                role = EXCLUDED.role,
                is_active = EXCLUDED.is_active,
                name_encrypted = EXCLUDED.name_encrypted,
                email_encrypted = EXCLUDED.email_encrypted,
                phone_encrypted = EXCLUDED.phone_encrypted,
                allow_scopes = EXCLUDED.allow_scopes
        """,
        (
            email_hash,
            auth_hash,
            emp["role"],
            emp["name"],
            email,
            emp.get("phone", ""),
            emp.get("preferences", ""),
            allow_scopes,
        ),
    )

print("   ✓ " + str(len(employees)) + " empleados creados")

# Create test customers
print("")
print("👤 Creando clientes de prueba...")

customers = [
    {
        "email": "cliente.ejemplo@test.com",
        "email_encrypted": "cliente.ejemplo@test.com",
        "name_encrypted": "Cliente Ejemplo",
        "phone_encrypted": "+5255555555",
        "contact_hash": "md5('cliente.ejemplo@test.com' + '+5255555555')",
    }
]

for cust in customers:
    email_encrypted = cust["email_encrypted"]
    phone_encrypted = cust["phone_encrypted"]
    contact_hash = cust["contact_hash"]
    name_encrypted = cust["name_encrypted"]

    cursor.execute(
        """
        INSERT INTO pronto_customers
            (email_hash, contact_hash, name_encrypted, email_encrypted, phone_encrypted, physical_description)
            VALUES (%s, %s, %s, %s, %s, 'Cliente de prueba')
        """,
        (email_encrypted, contact_hash, name_encrypted, phone_encrypted, phone_encrypted),
    )

print("   ✓ " + str(len(customers)) + " clientes creados")

# Create default business config
print("")
print("📋 Creando configuraciones por defecto...")

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
    ("restaurant_phone", "+52555555555"),
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

print("   ✓ " + str(len(default_configs)) + " configuraciones por defecto")

# Verify tables
print("")
print("📊 Verificando tablas creadas...")
cursor.execute(
    """
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
    ORDER BY table_name;
"""
)

tables = [row[0] for row in cursor.fetchall()]
print("✅ " + str(len(tables)) + " tablas en la base de datos:")
for table in sorted(tables):
    print("   - " + table)

# Close connection
cursor.close()
conn.close()

print("")
print("╔═══════════════════════════════════════════════════════════╗")
print("║                                                       ║")
print("║   ✅ DATOS DE PRUEBA CREADOS                ║")
print("║                                                       ║")
print("╚═══════════════════════════════════════════╗")
print("║                                                       ║")
print("╚═══════════════════════════════════════════════════════╗")
print("║                                                       ║")
print("║                                                       ║")
print("📊 Resumen:")
print("   • Conexión a PostgreSQL: OK")
print("   • 13 tablas creadas")
print("   • 4 empleados de prueba")
print("   • 2 clientes de prueba")
print("   • 6 items de menú")
print("   • 18 configuraciones por defecto")
print("")
print("🚀 Para iniciar el proyecto en modo debug:")
print("   bash bin/python/up-debug.sh")
print("")
