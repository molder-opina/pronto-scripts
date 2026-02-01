#!/usr/bin/env python3
"""
Script para inicializar configuración de PostgreSQL local.

Este script crea las configuraciones por defecto necesarias para que Pronto funcione.
"""

import os
import sys

try:
    import psycopg2
except ImportError:
    print("❌ Error: El paquete 'psycopg2-binary' no está instalado")
    print("   Para instalar: pip install psycopg2-binary")
    sys.exit(1)

print("╔═════════════════════════════════════════════════════╗")
print("║                                                       ║")
print("║   🗄️  INICIALIZANDO CONFIGURACIÓN POSTGRES 🗄️   ║")
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

# Check if pronto_business_config table exists
print("")
print("📋 Verificando tablas existentes...")
cursor.execute(
    """
    SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'pronto_business_config'
    );
"""
)
table_exists = cursor.fetchone()[0]

if not table_exists:
    print("📋 Creando tabla pronto_business_config...")
    cursor.execute(
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
else:
    print("✅ Tabla pronto_business_config ya existe")

# Create default configs
print("")
print("📊 Creando configuraciones por defecto...")

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
    "restaurant_email": ("noreply@cafeteria.test", "string"),
    "restaurant_phone": ("+5255555555", "string"),
    "restaurant_address": ("Av. Principal 123", "string"),
    "business_hours_start": ("08:00", "string"),
    "business_hours_end": ("22:00", "string"),
    "logo_url": ("/assets/cafeteria-test/logo.png", "string"),
    "primary_color": ("#FF5722", "string"),
    "secondary_color": ("#FFC107", "string"),
    "table_count": ("20", "int"),
    "enable_orders": ("true", "bool"),
    "enable_kitchen_display": ("true", "bool"),
    "enable_payments": ("true", "bool"),
}

created_count = 0
for key, (value, value_type) in default_configs.items():
    display_name = key.replace("_", " ").title()
    description = f"Default config for {display_name.lower()}"

    # Check if config already exists
    cursor.execute(
        """
        SELECT id FROM pronto_business_config WHERE config_key = %s;
    """,
        (key,),
    )

    existing = cursor.fetchone()

    if existing:
        # Update existing
        cursor.execute(
            """
            UPDATE pronto_business_config
            SET config_value = %s,
                value_type = %s,
                display_name = %s,
                description = %s,
                updated_at = CURRENT_TIMESTAMP
            WHERE config_key = %s;
        """,
            (value, value_type, display_name, description, key),
        )
        print(f"   ✓ Actualizado: {key} = {value}")
    else:
        # Create new
        cursor.execute(
            """
            INSERT INTO pronto_business_config
            (config_key, config_value, value_type, category, display_name, description)
            VALUES (%s, %s, %s, 'general', %s, %s);
        """,
            (key, value, value_type, display_name, description),
        )
        print(f"   ✓ Creado: {key} = {value}")
        created_count += 1

if created_count > 0:
    print(f"✅ {created_count} configuraciones nuevas creadas")
else:
    print("✅ Todas las configuraciones ya existen (actualizadas)")

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
print(f"✅ {len(tables)} tablas en la base de datos:")
for table in sorted(tables):
    print(f"   - {table}")

# Close connection
cursor.close()
conn.close()

print("")
print("╔═════════════════════════════════════════════════════╗")
print("║                                                       ║")
print("║   ✅ INICIALIZACIÓN COMPLETADA                     ║")
print("║                                                       ║")
print("╚═════════════════════════════════════════════════════╝")
print("")
print("🚀 Para iniciar el proyecto en modo debug:")
print("   bash bin/up-debug.sh")
print("")
