#!/usr/bin/env python3
"""
Script para migrar datos de Supabase a PostgreSQL local.

Este script:
1. Se conecta a Supabase y obtiene datos de todas las tablas necesarias
2. Se conecta a PostgreSQL local
3. Crea las tablas si no existen
4. Migra los datos desde Supabase a PostgreSQL local
"""

import os
import sys

try:
    from supabase import create_client
except ImportError:
    print("❌ Error: El paquete 'supabase' no está instalado")
    print("   Para instalar: pip install supabase")
    sys.exit(1)

try:
    import psycopg2
except ImportError:
    print("❌ Error: El paquete 'psycopg2-binary' no está instalado")
    print("   Para instalar: pip install psycopg2-binary")
    sys.exit(1)

print("╔═════════════════════════════════════════════════════╗")
print("║                                                       ║")
print("║   🔄 MIGRANDO DATOS DE SUPABASE A POSTGRESQL 🔄        ║")
print("║                                                       ║")
print("╚═════════════════════════════════════════════════════╝")
print("")

# Load configuration from environment
supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
postgres_host = os.getenv("POSTGRES_HOST", "localhost")
postgres_port = os.getenv("POSTGRES_PORT", "5432")
postgres_user = os.getenv("POSTGRES_USER", "pronto")
postgres_password = os.getenv("POSTGRES_PASSWORD", "pronto123")
postgres_db = os.getenv("POSTGRES_DB", "pronto")

if not supabase_url or not supabase_key:
    print("❌ Error: No se encontraron las credenciales de Supabase")
    print("   Asegúrate de que SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY estén configurados")
    sys.exit(1)

print("📊 Configuración:")
print(f"   Supabase: {supabase_url}")
print(f"   PostgreSQL: {postgres_user}@{postgres_host}:{postgres_port}/{postgres_db}")
print("")

# Connect to Supabase
print("📡 Conectando a Supabase...")
try:
    supabase = create_client(supabase_url, supabase_key)
    print("✅ Conectado a Supabase")
except Exception as e:
    print(f"❌ Error al conectar a Supabase: {e}")
    sys.exit(1)

# Connect to PostgreSQL local
print("🗄️  Conectando a PostgreSQL local...")
try:
    pg_conn = psycopg2.connect(
        host=postgres_host,
        port=postgres_port,
        user=postgres_user,
        password=postgres_password,
        database=postgres_db,
    )
    pg_conn.autocommit = True
    pg_cursor = pg_conn.cursor()
    print("✅ Conectado a PostgreSQL local")
except Exception as e:
    print(f"❌ Error al conectar a PostgreSQL local: {e}")
    sys.exit(1)

# Create tables in PostgreSQL
print("")
print("📋 Creando tablas en PostgreSQL local...")

# Table definitions with PostgreSQL syntax (no AUTO_INCREMENT)
table_definitions = {
    "pronto_customers": """
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
    """,
    "pronto_employees": """
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
    """,
    "pronto_dining_sessions": """
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
    """,
    "pronto_menu_categories": """
        CREATE TABLE IF NOT EXISTS pronto_menu_categories (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            description TEXT,
            display_order INTEGER DEFAULT 0,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """,
    "pronto_menu_items": """
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
    """,
    "pronto_orders": """
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
    """,
    "pronto_order_items": """
        CREATE TABLE IF NOT EXISTS pronto_order_items (
            id SERIAL PRIMARY KEY,
            order_id INTEGER REFERENCES pronto_orders(id) ON DELETE CASCADE,
            menu_item_id INTEGER REFERENCES pronto_menu_items(id) ON DELETE SET NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            unit_price NUMERIC(10,2) NOT NULL DEFAULT 0,
            notes TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """,
    "pronto_business_config": """
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
    """,
    "pronto_business_info": """
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
    """,
}

# Create tables
for table_name, ddl in table_definitions.items():
    try:
        pg_cursor.execute(ddl)
        print(f"   ✓ Tabla {table_name} creada")
    except Exception as e:
        print(f"   ⚠️  Error creando tabla {table_name}: {e}")

print("")
print("📊 Migrando datos desde Supabase...")

# Migrate data from Supabase
migrated = {
    "pronto_business_config": 0,
    "pronto_business_info": 0,
    "pronto_menu_categories": 0,
    "pronto_menu_items": 0,
    "pronto_customers": 0,
    "pronto_employees": 0,
    "pronto_orders": 0,
    "pronto_order_items": 0,
    "pronto_dining_sessions": 0,
}

# Migrate pronto_business_config
print("   → pronto_business_config")
try:
    response = supabase.table("pronto_business_config").select("*").execute()
    if hasattr(response, "data") and response.data:
        configs = response.data
        for config in configs:
            config_key = config.get("config_key")
            if not config_key:
                continue

            pg_cursor.execute(
                """
                SELECT id FROM pronto_business_config WHERE config_key = %s;
            """,
                (config_key,),
            )

            existing = pg_cursor.fetchone()

            if existing:
                pg_cursor.execute(
                    """
                    UPDATE pronto_business_config
                    SET config_value = %s, value_type = %s, category = %s,
                        display_name = %s, description = %s
                    WHERE config_key = %s;
                """,
                    (
                        config.get("config_value", ""),
                        config.get("value_type", "string"),
                        config.get("category", "general"),
                        config.get("display_name", config_key),
                        config.get("description", ""),
                        config_key,
                    ),
                )
            else:
                pg_cursor.execute(
                    """
                    INSERT INTO pronto_business_config
                    (config_key, config_value, value_type, category, display_name, description)
                    VALUES (%s, %s, %s, 'general', %s, %s);
                """,
                    (
                        config_key,
                        config.get("config_value", ""),
                        config.get("value_type", "string"),
                        config.get("display_name", config_key),
                        config.get("description", ""),
                    ),
                )
        migrated["pronto_business_config"] = len(configs) if hasattr(response, "data") else 0
except Exception as e:
    print(f"      ⚠️  Error migrando pronto_business_config: {e}")

# Migrate pronto_business_info
print("   → pronto_business_info")
try:
    response = supabase.table("pronto_business_info").select("*").execute()
    if hasattr(response, "data") and response.data:
        infos = response.data
        for info in infos:
            if not info.get("slug"):
                continue

            pg_cursor.execute(
                """
                SELECT id FROM pronto_business_info WHERE slug = %s;
            """,
                (info.get("slug"),),
            )

            existing = pg_cursor.fetchone()

            if existing:
                pg_cursor.execute(
                    """
                    UPDATE pronto_business_info
                    SET restaurant_name = %s, description = %s, logo_url = %s, timezone = %s, currency = %s
                    WHERE slug = %s;
                """,
                    (
                        info.get("restaurant_name", ""),
                        info.get("description", ""),
                        info.get("logo_url", ""),
                        info.get("timezone", "America/Mexico_City"),
                        "MXN",
                        info.get("slug"),
                    ),
                )
            else:
                pg_cursor.execute(
                    """
                    INSERT INTO pronto_business_info
                    (restaurant_name, slug, description, logo_url, timezone, currency)
                    VALUES (%s, %s, %s, %s, %s, 'MXN');
                """,
                    (
                        info.get("restaurant_name", ""),
                        info.get("slug", ""),
                        info.get("description", ""),
                        info.get("logo_url", ""),
                        info.get("timezone", "America/Mexico_City"),
                    ),
                )
        migrated["pronto_business_info"] = len(infos) if hasattr(response, "data") else 0
except Exception as e:
    print(f"      ⚠️  Error migrando pronto_business_info: {e}")

# Migrate pronto_menu_categories
print("   → pronto_menu_categories")
try:
    response = supabase.table("pronto_menu_categories").select("*").execute()
    if hasattr(response, "data") and response.data:
        categories = response.data
        for category in categories:
            pg_cursor.execute(
                """
                SELECT id FROM pronto_menu_categories WHERE name = %s;
            """,
                (category.get("name"),),
            )

            existing = pg_cursor.fetchone()

            if existing:
                pg_cursor.execute(
                    """
                    UPDATE pronto_menu_categories
                    SET description = %s, display_order = %s, is_active = %s
                    WHERE name = %s;
                """,
                    (
                        category.get("description", ""),
                        category.get("display_order", 0),
                        category.get("is_active", True)
                        if category.get("is_active") is not None
                        else False,
                        category.get("name"),
                    ),
                )
            else:
                pg_cursor.execute(
                    """
                    INSERT INTO pronto_menu_categories
                    (name, description, display_order, is_active)
                    VALUES (%s, %s, %s, %s);
                """,
                    (
                        category.get("name", ""),
                        category.get("description", ""),
                        category.get("display_order", 0),
                        category.get("is_active") is not None,
                    ),
                )
        migrated["pronto_menu_categories"] = len(categories) if hasattr(response, "data") else 0
except Exception as e:
    print(f"      ⚠️  Error migrando pronto_menu_categories: {e}")

# Migrate pronto_menu_items
print("   → pronto_menu_items")
try:
    response = supabase.table("pronto_menu_items").select("*").execute()
    if hasattr(response, "data") and response.data:
        items = response.data
        for item in items:
            if not item.get("category_id"):
                continue

            pg_cursor.execute(
                """
                SELECT id FROM pronto_menu_items WHERE name = %s AND category_id = %s;
            """,
                (item.get("name"), item.get("category_id")),
            )

            existing = pg_cursor.fetchone()

            if existing:
                pg_cursor.execute(
                    """
                    UPDATE pronto_menu_items
                    SET description = %s, price = %s, image_url = %s, is_available = %s, display_order = %s
                    WHERE name = %s AND category_id = %s;
                """,
                    (
                        item.get("description", ""),
                        item.get("price", 0),
                        item.get("image_url", ""),
                        item.get("is_available", True)
                        if item.get("is_available") is not None
                        else False,
                        item.get("display_order", 0),
                        item.get("name"),
                        item.get("category_id"),
                    ),
                )
            else:
                pg_cursor.execute(
                    """
                    INSERT INTO pronto_menu_items
                    (category_id, name, description, price, image_url, is_available, display_order)
                    VALUES (%s, %s, %s, %s, %s, %s, %s);
                """,
                    (
                        item.get("category_id"),
                        item.get("name", ""),
                        item.get("description", ""),
                        item.get("price", 0),
                        item.get("image_url", ""),
                        item.get("is_available") is not None,
                        0,
                    ),
                )
        migrated["pronto_menu_items"] = len(items) if hasattr(response, "data") else 0
except Exception as e:
    print(f"      ⚠️  Error migrando pronto_menu_items: {e}")

# Migrate pronto_customers
print("   → pronto_customers")
try:
    response = supabase.table("pronto_customers").select("*").execute()
    if hasattr(response, "data") and response.data:
        customers = response.data
        for customer in customers:
            if not customer.get("email_hash"):
                continue

            pg_cursor.execute(
                """
                SELECT id FROM pronto_customers WHERE email_hash = %s;
            """,
                (customer.get("email_hash"),),
            )

            existing = pg_cursor.fetchone()

            if existing:
                pg_cursor.execute(
                    """
                    UPDATE pronto_customers
                    SET physical_description = %s, avatar = %s
                    WHERE email_hash = %s;
                """,
                    (
                        customer.get("physical_description", "")
                        if customer.get("physical_description") is not None
                        else "",
                        customer.get("avatar", "") if customer.get("avatar") is not None else "",
                        customer.get("email_hash"),
                    ),
                )
            else:
                pg_cursor.execute(
                    """
                    INSERT INTO pronto_customers
                    (email_hash, contact_hash, name_encrypted, email_encrypted, phone_encrypted, physical_description)
                    VALUES (%s, %s, %s, %s, %s, %s);
                """,
                    (
                        customer.get("email_hash", ""),
                        customer.get("contact_hash", ""),
                        customer.get("name_encrypted", ""),
                        customer.get("email_encrypted", ""),
                        customer.get("phone_encrypted", ""),
                        customer.get("physical_description", "")
                        if customer.get("physical_description") is not None
                        else "",
                    ),
                )
        migrated["pronto_customers"] = len(customers) if hasattr(response, "data") else 0
except Exception as e:
    print(f"      ⚠️  Error migrando pronto_customers: {e}")

# Migrate pronto_employees
print("   → pronto_employees")
try:
    response = supabase.table("pronto_employees").select("*").execute()
    if hasattr(response, "data") and response.data:
        employees = response.data
        for employee in employees:
            if not employee.get("email_hash"):
                continue

            pg_cursor.execute(
                """
                SELECT id FROM pronto_employees WHERE email_hash = %s;
            """,
                (employee.get("email_hash"),),
            )

            existing = pg_cursor.fetchone()

            if existing:
                pg_cursor.execute(
                    """
                    UPDATE pronto_employees
                    SET role = %s, is_active = %s, preferences = %s, avatar = %s
                    WHERE email_hash = %s;
                """,
                    (
                        employee.get("role", ""),
                        employee.get("is_active") is not None,
                        employee.get("preferences", "")
                        if employee.get("preferences") is not None
                        else "",
                        employee.get("avatar", "") if employee.get("avatar") is not None else "",
                        employee.get("email_hash"),
                    ),
                )
            else:
                pg_cursor.execute(
                    """
                    INSERT INTO pronto_employees
                    (email_hash, role, name_encrypted, email_encrypted, phone_encrypted, preferences, is_active)
                    VALUES (%s, %s, %s, %s, %s, %s, %s);
                """,
                    (
                        employee.get("email_hash", ""),
                        employee.get("role", ""),
                        employee.get("name_encrypted", ""),
                        employee.get("email_encrypted", ""),
                        employee.get("phone_encrypted", ""),
                        employee.get("preferences", "")
                        if employee.get("preferences") is not None
                        else "",
                        True,
                    ),
                )
        migrated["pronto_employees"] = len(employees) if hasattr(response, "data") else 0
except Exception as e:
    print(f"      ⚠️  Error migrando pronto_employees: {e}")

# Migrate pronto_orders
print("   → pronto_orders")
try:
    response = supabase.table("pronto_orders").select("*").execute()
    if hasattr(response, "data") and response.data:
        orders = response.data
        for order in orders:
            if not order.get("id"):
                continue

            pg_cursor.execute(
                """
                SELECT id FROM pronto_orders WHERE id = %s;
            """,
                (order.get("id"),),
            )

            existing = pg_cursor.fetchone()

            if existing:
                pg_cursor.execute(
                    """
                    UPDATE pronto_orders
                    SET workflow_status = %s, payment_status = %s, subtotal = %s, tax_amount = %s, tip_amount = %s, total_amount = %s, notes = %s
                    WHERE id = %s;
                """,
                    (
                        order.get("workflow_status", "requested"),
                        order.get("payment_status", "unpaid"),
                        order.get("subtotal", 0),
                        order.get("tax_amount", 0),
                        order.get("tip_amount", 0),
                        order.get("total_amount", 0),
                        order.get("notes", "") if order.get("notes") is not None else "",
                        order.get("id"),
                    ),
                )
            else:
                pg_cursor.execute(
                    """
                    INSERT INTO pronto_orders
                    (customer_id, session_id, workflow_status, payment_status, subtotal, tax_amount, tip_amount, total_amount)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s);
                """,
                    (
                        order.get("customer_id") if order.get("customer_id") else "NULL",
                        order.get("session_id") if order.get("session_id") else "NULL",
                        order.get("workflow_status", "requested"),
                        order.get("payment_status", "unpaid"),
                        order.get("subtotal", 0),
                        order.get("tax_amount", 0),
                        order.get("tip_amount", 0),
                        order.get("total_amount", 0),
                    ),
                )
        migrated["pronto_orders"] = len(orders) if hasattr(response, "data") else 0
except Exception as e:
    print(f"      ⚠️  Error migrando pronto_orders: {e}")

# Migrate pronto_order_items
print("   → pronto_order_items")
try:
    response = supabase.table("pronto_order_items").select("*").execute()
    if hasattr(response, "data") and response.data:
        order_items = response.data
        for order_item in order_items:
            if not order_item.get("id"):
                continue

            pg_cursor.execute(
                """
                SELECT id FROM pronto_order_items WHERE id = %s;
            """,
                (order_item.get("id"),),
            )

            existing = pg_cursor.fetchone()

            if existing:
                pg_cursor.execute(
                    """
                    UPDATE pronto_order_items
                    SET quantity = %s, unit_price = %s, notes = %s
                    WHERE id = %s;
                """,
                    (
                        order_item.get("quantity", 1),
                        order_item.get("unit_price", 0),
                        order_item.get("notes", "") if order_item.get("notes") is not None else "",
                        order_item.get("id"),
                    ),
                )
            else:
                pg_cursor.execute(
                    """
                    INSERT INTO pronto_order_items
                    (order_id, menu_item_id, quantity, unit_price, notes)
                    VALUES (%s, %s, %s, %s, %s);
                """,
                    (
                        order_item.get(
                            "order_id",
                        ),
                        order_item.get("menu_item_id"),
                        order_item.get("quantity", 1),
                        order_item.get("unit_price", 0),
                        order_item.get("notes", "") if order_item.get("notes") is not None else "",
                    ),
                )
        migrated["pronto_order_items"] = len(order_items) if hasattr(response, "data") else 0
except Exception as e:
    print(f"      ⚠️  Error migrando pronto_order_items: {e}")

# Migrate pronto_dining_sessions
print("   → pronto_dining_sessions")
try:
    response = supabase.table("pronto_dining_sessions").select("*").execute()
    if hasattr(response, "data") and response.data:
        sessions = response.data
        for session in sessions:
            if not session.get("table_id"):
                continue

            pg_cursor.execute(
                """
                SELECT id FROM pronto_dining_sessions WHERE table_id = %s;
            """,
                (session.get("table_id"),),
            )

            existing = pg_cursor.fetchone()

            if existing:
                pg_cursor.execute(
                    """
                    UPDATE pronto_dining_sessions
                    SET session_type = %s, guests = %s, notes = %s
                    WHERE table_id = %s;
                """,
                    (
                        session.get("session_type", "normal"),
                        session.get("guests", 1) if session.get("guests") is not None else 0,
                        session.get("notes", "") if session.get("notes") is not None else "",
                        session.get("table_id"),
                    ),
                )
            else:
                pg_cursor.execute(
                    """
                    INSERT INTO pronto_dining_sessions
                    (table_id, session_type, customer_id, guests, notes)
                    VALUES (%s, %s, %s, %s, %s);
                """,
                    (
                        session.get("table_id"),
                        session.get("session_type", "normal"),
                        session.get("customer_id") if session.get("customer_id") else "NULL",
                        session.get("guests", 1) if session.get("guests") is not None else 0,
                        session.get("notes", "") if session.get("notes") is not None else "",
                    ),
                )
        migrated["pronto_dining_sessions"] = len(sessions) if hasattr(response, "data") else 0
except Exception as e:
    print(f"      ⚠️  Error migrando pronto_dining_sessions: {e}")

# Close connections
pg_cursor.close()
pg_conn.close()

print("")
print("╔═══════════════════════════════════════════════════╗")
print("║                                                       ║")
print("║   ✅ MIGRACIÓN COMPLETADA                         ║")
print("║                                                       ║")
print("╚═════════════════════════════════════════════════════════╝")
print("")
print("📊 Resumen de migración:")
for table_name, count in migrated.items():
    print(f"   • {table_name}: {count} registros")
print("")
print("🚀 Para iniciar el proyecto en modo debug:")
print("   bash bin/up-debug.sh")
print("")
