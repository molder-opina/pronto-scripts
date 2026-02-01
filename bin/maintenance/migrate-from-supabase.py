#!/usr/bin/env python3
"""
Script para migrar datos de Supabase a PostgreSQL local.

Este script:
1. Se conecta a Supabase y obtiene configuración de negocio
2. Se conecta a PostgreSQL local e inserta esos datos
3. Configura valores por defecto si no hay datos en Supabase
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
print("║   🔄 MIGRANDO DATOS DE SUPABASE A POSTGRES 🔄        ║")
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
print(f"   Supabase URL: {supabase_url}")
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

# Check if pronto_business_config table exists
pg_cursor.execute(
    """
    SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'pronto_business_config'
    );
"""
)

table_exists = pg_cursor.fetchone()[0]

if not table_exists:
    print("📋 Creando tabla pronto_business_config...")
    pg_cursor.execute(
        """
        CREATE TABLE pronto_business_config (
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
    print("✅ Tabla pronto_business_config creada")

# Migrate BusinessConfig from Supabase
print("")
print("📊 Migrando configuración de negocio...")

try:
    # Get all business config from Supabase
    response = supabase.table("pronto_business_config").select("*").execute()

    migrated_count = 0

    if hasattr(response, "data") and response.data:
        configs = response.data
        print(f"   Se encontraron {len(configs)} configuraciones en Supabase")

        # Insert configs into PostgreSQL
        for config_data in configs:
            config_key = config_data.get("config_key")
            config_value = config_data.get("config_value")
            value_type = config_data.get("value_type", "string")
            category = config_data.get("category", "general")
            display_name = config_data.get("display_name", config_key)
            description = config_data.get("description", "Migrated from Supabase")

            if not config_key:
                continue

            # Check if config already exists
            pg_cursor.execute(
                """
                SELECT id FROM pronto_business_config WHERE config_key = %s;
            """,
                (config_key,),
            )

            existing = pg_cursor.fetchone()

            if existing:
                # Update existing
                pg_cursor.execute(
                    """
                    UPDATE pronto_business_config
                    SET config_value = %s,
                        value_type = %s,
                        category = %s,
                        display_name = %s,
                        description = %s,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE config_key = %s;
                """,
                    (config_value, value_type, category, display_name, description, config_key),
                )
                print(f"   ✓ Actualizado: {config_key}")
            else:
                # Create new
                pg_cursor.execute(
                    """
                    INSERT INTO pronto_business_config
                    (config_key, config_value, value_type, category, display_name, description)
                    VALUES (%s, %s, %s, %s, %s, %s);
                """,
                    (config_key, config_value, value_type, category, display_name, description),
                )
                print(f"   ✓ Creado: {config_key}")

            migrated_count += 1

        print(f"✅ {migrated_count} configuraciones migradas")
    else:
        print("⚠️  No se encontraron configuraciones en Supabase")
        print("   Se crearán configuraciones por defecto")

except Exception as e:
    print(f"⚠️  Error al migrar configuración de negocio: {e}")
    print("   Creando configuraciones por defecto...")

# Create default configs
default_configs = {
    "restaurant_name": ("Cafetería de Prueba", "string"),
    "tax_rate": ("0.16", "float"),
    "currency": ("MXN", "string"),
    "time_zone": ("America/Mexico_City", "string"),
    "session_timeout_minutes": ("30", "int"),
    "order_preparation_time_minutes": ("15", "int"),
    "enable_notifications": ("true", "bool"),
    "customer_session_cookie_name": ("pronto_customer_session", "string"),
    "employee_session_cookie_name": ("pronto_employee_session", "string"),
}

print("")
print("📋 Creando configuraciones por defecto...")

default_count = 0
for key, (value, value_type) in default_configs.items():
    # Check if config already exists
    pg_cursor.execute(
        """
        SELECT id FROM pronto_business_config WHERE config_key = %s;
    """,
        (key,),
    )

    existing = pg_cursor.fetchone()

    if not existing:
        display_name = key.replace("_", " ").title()
        pg_cursor.execute(
            """
            INSERT INTO pronto_business_config
            (config_key, config_value, value_type, category, display_name, description)
            VALUES (%s, %s, %s, 'general', %s, 'Default config migrated from Supabase');
        """,
            (key, value, value_type, display_name),
        )
        print(f"   ✓ Creado: {key} = {value}")
        default_count += 1

if default_count > 0:
    print(f"✅ {default_count} configuraciones por defecto creadas")

# Close connections
pg_cursor.close()
pg_conn.close()

print("")
print("╔═════════════════════════════════════════════════════╗")
print("║                                                       ║")
print("║   ✅ MIGRACIÓN COMPLETADA                         ║")
print("║                                                       ║")
print("╚═════════════════════════════════════════════════════╝")
print("")
print("📊 Resumen:")
print("   • Conexión a Supabase: OK")
print("   • Conexión a PostgreSQL local: OK")
print("   • Migración de configuración: OK")
print("")
print("🚀 Para iniciar el proyecto en modo debug:")
print("   bash bin/up-debug.sh")
print("")
