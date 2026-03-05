#!/usr/bin/env python3
"""
Script para cargar datos de seed en PostgreSQL para Pronto.

Este script carga todos los datos iniciales necesarios:
- Áreas (Interior, Terraza, Bar, VIP)
- Mesas con códigos QR
- Configuración de negocio
- Configuración del sistema
- Permisos de rutas
- Categorías del menú
- Productos del menú
- Modificadores
- Períodos del día
- Empleados de ejemplo

Uso:
    python bin/init-seed.py
    POSTGRES_HOST=localhost python bin/init-seed.py
"""

from __future__ import annotations

import os
import sys

# Add build directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "build"))


# Load seed-specific env file if present
def _load_env_file(path: str) -> None:
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip())


_load_env_file(os.path.join(os.path.dirname(__file__), "..", "scripts", "init", "seed.env"))

# Validate required environment variables
if not os.getenv("SECRET_KEY"):
    raise RuntimeError("SECRET_KEY is required")
if not os.getenv("PASSWORD_HASH_SALT"):
    raise RuntimeError("PASSWORD_HASH_SALT is required")


def init_seed_data():
    """Initialize all seed data in the database."""
    from sqlalchemy import create_engine, text
    from sqlalchemy.orm import scoped_session, sessionmaker

    # Load configuration from environment
    postgres_host = os.getenv("POSTGRES_HOST", "localhost")
    postgres_port = os.getenv("POSTGRES_PORT", "5432")
    postgres_user = os.getenv("POSTGRES_USER", "pronto")
    postgres_password = os.getenv("POSTGRES_PASSWORD", "pronto123")
    postgres_db = os.getenv("POSTGRES_DB", "pronto")

    # Build connection URL
    database_url = f"postgresql://{postgres_user}:{postgres_password}@{postgres_host}:{postgres_port}/{postgres_db}"

    print("╔═══════════════════════════════════════════════════╗")
    print("║                                                       ║")
    print("║   🌱 CARGANDO DATOS DE SEED PARA PRONTO 🌱  ║")
    print("║                                                       ║")
    print("╚═════════════════════════════════════════════════════╝")
    print("")
    print("📊 Configuración:")
    print(f"   Host: {postgres_host}:{postgres_port}")
    print(f"   Usuario: {postgres_user}")
    print(f"   Base de datos: {postgres_db}")
    print("")

    # Create engine
    print("🔗 Conectando a PostgreSQL...")
    try:
        engine = create_engine(database_url, pool_pre_ping=True)
        Session = sessionmaker(bind=engine)

        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        print("✅ Conectado a PostgreSQL")
    except Exception as e:
        print(f"❌ Error al conectar a PostgreSQL: {e}")
        sys.exit(1)

    # Import and run seed functions
    from pronto_shared.models import Area, SystemSetting, Table
    from pronto_shared.services.seed import ensure_seed_data

    with Session() as session:
        print("")
        print("📋 Cargando datos...")

        # ========================================================================
        # STEP 1: CREATE AREAS FIRST (required for table-area relationship)
        # ========================================================================
        print("   🏢 Creando áreas (REQUIRED for table-area FK)...")

        # Areas con códigos A-Z (configurables)
        areas_to_create = [
            {
                "name": "Interior",
                "prefix": "A",
                "color": "#4CAF50",
                "description": "Interior del restaurante",
            },
            {
                "name": "Terraza",
                "prefix": "B",
                "color": "#2196F3",
                "description": "Terraza exterior",
            },
            {"name": "Bar", "prefix": "C", "color": "#FF9800", "description": "Área de bar"},
            {"name": "VIP", "prefix": "D", "color": "#9C27B0", "description": "Zona VIP"},
        ]

        existing_areas = session.execute(text("SELECT name FROM pronto_areas")).fetchall()
        existing_names = [a[0] for a in existing_areas]

        areas_created = 0
        for area_data in areas_to_create:
            if area_data["name"] not in existing_names:
                area = Area(
                    name=area_data["name"],
                    prefix=area_data["prefix"],
                    color=area_data["color"],
                    description=area_data["description"],
                )
                session.add(area)
                areas_created += 1

        if areas_created > 0:
            session.commit()
            print(f"      ✓ {areas_created} áreas creadas")
        else:
            print("      ✓ Áreas ya existen")

        # Verify areas were created
        area_count = session.execute(text("SELECT COUNT(*) FROM pronto_areas")).fetchone()[0]
        if area_count == 0:
            raise Exception("CRITICAL: No areas were created! Tables require area_id FK.")
        print(f"      ✓ {area_count} áreas disponibles en DB")

        # ========================================================================
        # STEP 2: CREATE OR UPDATE TABLES WITH area_id (REQUIRED, NOT NULL)
        # ========================================================================
        print("   🪑 Verificando/creando mesas con área asignada...")

        # Get area IDs mapped by prefix
        areas = {
            a[0]: a[1]
            for a in session.execute(text("SELECT prefix, id FROM pronto_areas")).fetchall()
        }

        # Prefix to area ID mapping
        prefix_to_area = {
            "A": areas.get("A"),  # Interior
            "B": areas.get("B"),  # Terraza
            "C": areas.get("C"),  # Bar
            "D": areas.get("D"),  # VIP
        }

        # Update existing tables with area_id based on prefix in current code
        updates = 0
        for prefix, area_id in prefix_to_area.items():
            if area_id:
                result = session.execute(
                    text("UPDATE pronto_tables SET area_id = :area_id WHERE code LIKE :pattern"),
                    {"area_id": area_id, "pattern": f"{prefix}-M%"},
                )
                updates += result.rowcount

        if updates > 0:
            session.commit()
            print(f"      ✓ {updates} mesas actualizadas con area_id")

        # Verify all tables have area_id
        tables_without_area = session.execute(
            text("SELECT COUNT(*) FROM pronto_tables WHERE area_id IS NULL")
        ).fetchone()[0]

        if tables_without_area > 0:
            print(f"      ⚠️  {tables_without_area} mesas sin área - asignando default...")
            # Assign default area (A = Interior) to tables without area
            default_area = areas.get("A")
            if default_area:
                session.execute(
                    text("UPDATE pronto_tables SET area_id = :area_id WHERE area_id IS NULL"),
                    {"area_id": default_area},
                )
                session.commit()
                print(f"      ✓ Mesas sin área asignadas a Interior/A (default)")

        # Verify no NULL area_id
        tables_without_area = session.execute(
            text("SELECT COUNT(*) FROM pronto_tables WHERE area_id IS NULL")
        ).fetchone()[0]

        if tables_without_area > 0:
            raise Exception(
                f"CRITICAL: {tables_without_area} tables still have NULL area_id! FK constraint will fail."
            )
        print(f"      ✓ Todas las mesas tienen área asignada (area_id NOT NULL)")

        # ========================================================================
        # STEP 2B: CREATE TABLES WITH PROPER CODES IF NOT EXIST
        # ========================================================================
        print("   🪑 Verificando/creando mesas con códigos A-M01, B-M02, etc...")

        # Get area IDs and prefixes
        area_data = session.execute(
            text("SELECT id, prefix FROM pronto_areas WHERE is_active = true ORDER BY prefix")
        ).fetchall()

        if not area_data:
            raise Exception("CRITICAL: No active areas found! Cannot create tables.")

        # Table distribution by area (can customize counts)
        table_distribution = {
            "A": 15,  # Interior
            "B": 8,  # Terraza
            "C": 4,  # Bar
            "D": 3,  # VIP
        }

        tables_created = 0
        for area_id, prefix in area_data:
            count = table_distribution.get(prefix, 5)  # Default 5 tables per area
            for num in range(1, count + 1):
                table_code = f"{prefix}-M{num:02d}"  # A-M01, B-M05, etc.

                # Check if table with this code already exists
                existing = session.execute(
                    text("SELECT id FROM pronto_tables WHERE code = :code"), {"code": table_code}
                ).fetchone()

                if not existing:
                    # Generate QR code
                    import hashlib
                    import time

                    restaurant_slug = (
                        os.getenv("RESTAURANT_NAME", "pronto").lower().replace(" ", "-")
                    )
                    qr_id = hashlib.sha256(
                        f"{restaurant_slug}-{table_code}-{int(time.time())}".encode()
                    ).hexdigest()[:16]

                    session.execute(
                        text(
                            "INSERT INTO pronto_tables (code, qr_id, area_id, is_active, created_at, updated_at) "
                            "VALUES (:code, :qr_id, :area_id, true, NOW(), NOW())"
                        ),
                        {"code": table_code, "qr_id": qr_id, "area_id": area_id},
                    )
                    tables_created += 1

        if tables_created > 0:
            session.commit()
            print(f"      ✓ {tables_created} mesas creadas con códigos correctos")
        else:
            print("      ✓ Todas las mesas ya existen con códigos correctos")

        # ========================================================================
        # STEP 3: Load full seed data (categories, products, etc.)
        # ========================================================================
        print("   📦 Cargando datos completos de seed...")
        try:
            ensure_seed_data(session)
            session.commit()
            print("      ✓ Datos de seed cargados exitosamente")
        except Exception as e:
            print(f"      ⚠️  Error en ensure_seed_data: {e}")
            session.rollback()

        # Create system settings
        print("   ⚙️  Creando configuraciones del sistema...")
        default_settings = [
            ("restaurant_name", "Mi Restaurante", "string", "Nombre del restaurante", "general"),
            ("restaurant_slug", "mi-restaurante", "string", "Slug URL del restaurante", "general"),
            ("timezone", "America/Mexico_City", "string", "Zona horaria", "general"),
            ("currency", "MXN", "string", "Código de moneda", "general"),
            ("tax_rate", "16.00", "float", "Porcentaje de impuestos", "tax"),
            ("tax_included", "false", "bool", "Si el precio incluye impuestos", "tax"),
            ("max_order_items", "50", "int", "Máximo de items por orden", "orders"),
            ("order_timeout_minutes", "30", "int", "Timeout para órdenes", "orders"),
            ("session_timeout_hours", "4", "int", "Timeout de sesión", "sessions"),
            ("auto_close_session_hours", "12", "int", "Cierre automático de sesiones", "sessions"),
            (
                "notify_waiter_on_order",
                "true",
                "bool",
                "Notificar mesero al ordenar",
                "notifications",
            ),
            (
                "notify_kitchen_on_order",
                "true",
                "bool",
                "Notificar cocina al ordenar",
                "notifications",
            ),
        ]

        existing_settings = session.execute(
            text("SELECT key FROM pronto_system_settings")
        ).fetchall()
        existing_keys = [s[0] for s in existing_settings]

        settings_created = 0
        for key, value, val_type, desc, category in default_settings:
            if key not in existing_keys:
                setting = SystemSetting(
                    key=key,
                    value=value,
                    value_type=val_type,
                    description=desc,
                    category=category,
                )
                session.add(setting)
                settings_created += 1

        if settings_created > 0:
            session.commit()
            print(f"      ✓ {settings_created} configuraciones creadas")
        else:
            print("      ✓ Configuraciones ya existen")

        # Print summary
        print("")
        print("=" * 60)
        print("📊 RESUMEN DE DATOS CARGADOS")
        print("=" * 60)

        stats = {
            "Áreas": session.execute(text("SELECT COUNT(*) FROM pronto_areas")).fetchone()[0],
            "Mesas": session.execute(text("SELECT COUNT(*) FROM pronto_tables")).fetchone()[0],
            "Categorías": session.execute(
                text("SELECT COUNT(*) FROM pronto_menu_categories")
            ).fetchone()[0],
            "Productos": session.execute(text("SELECT COUNT(*) FROM pronto_menu_items")).fetchone()[
                0
            ],
            "Modificadores": session.execute(
                text("SELECT COUNT(*) FROM pronto_modifiers")
            ).fetchone()[0],
            "Configuración": session.execute(
                text("SELECT COUNT(*) FROM pronto_business_config")
            ).fetchone()[0],
            "System Settings": session.execute(
                text("SELECT COUNT(*) FROM pronto_system_settings")
            ).fetchone()[0],
            "Empleados": session.execute(text("SELECT COUNT(*) FROM pronto_employees")).fetchone()[
                0
            ],
            "Clientes": session.execute(text("SELECT COUNT(*) FROM pronto_customers")).fetchone()[
                0
            ],
        }

        for key, value in stats.items():
            print(f"   {key}: {value}")

        print("=" * 60)

    # Close engine
    engine.dispose()

    print("")
    print("╔═══════════════════════════════════════════════════╗")
    print("║                                                       ║")
    print("║   ✅ DATOS DE SEED CARGADOS EXITOSAMENTE       ║")
    print("║                                                       ║")
    print("╚═════════════════════════════════════════════════════╝")
    print("")


if __name__ == "__main__":
    init_seed_data()
