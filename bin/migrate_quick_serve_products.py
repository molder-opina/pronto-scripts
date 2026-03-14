#!/usr/bin/env python3
"""
Migrate existing menu items to set is_quick_serve flag based on category.

This script analyzes existing menu items and sets is_quick_serve=True
for items in beverage categories.
"""

import argparse
import os
import sys
from typing import List

try:
    import psycopg2
except ImportError:
    print("❌ Error: El paquete 'psycopg2-binary' no está instalado")
    print("   Para instalar: pip install psycopg2-binary")
    sys.exit(1)

# Load database configuration from environment
postgres_host = os.getenv("POSTGRES_HOST", "localhost")
postgres_port = os.getenv("POSTGRES_PORT", "5432")
postgres_user = os.getenv("POSTGRES_USER", "pronto")
postgres_password = os.getenv("POSTGRES_PASSWORD", "pronto123")
postgres_db = os.getenv("POSTGRES_DB", "pronto")

# Categories that should be quick serve (beverages, etc.)
QUICK_SERVE_CATEGORIES = [
    "beverages",
    "water",
    "coffee",
    "soft_drinks",
    "beer",
    "wine",
    "alcohol",
    "drinks",
    "soda",
    "juice",
]


def get_quick_serve_categories(cursor) -> List[str]:
    """Get all category slugs that should be quick serve."""
    query = """
        SELECT slug 
        FROM pronto_menu_categories 
        WHERE LOWER(slug) = ANY(%s)
    """
    cursor.execute(query, (QUICK_SERVE_CATEGORIES,))
    return [row[0] for row in cursor.fetchall()]


def migrate_quick_serve_items(cursor, dry_run: bool = False) -> int:
    """Migrate menu items to set is_quick_serve flag."""
    # Get quick serve categories
    quick_serve_categories = get_quick_serve_categories(cursor)
    if not quick_serve_categories:
        print("ℹ️  No se encontraron categorías de bebidas para migrar")
        return 0

    print(f"📊 Categorías identificadas como quick-serve: {quick_serve_categories}")

    # Count items that will be updated
    count_query = """
        SELECT COUNT(*) 
        FROM pronto_menu_items mi
        JOIN pronto_menu_categories mc ON mi.category_id = mc.id
        WHERE mc.slug = ANY(%s) AND mi.is_quick_serve = false
    """
    cursor.execute(count_query, (quick_serve_categories,))
    count_to_update = cursor.fetchone()[0]

    if count_to_update == 0:
        print("✅ No hay items que necesiten actualización")
        return 0

    print(f"🔄 Items que serán actualizados: {count_to_update}")

    if dry_run:
        print("🔍 Modo dry-run: No se realizarán cambios")
        return count_to_update

    # Update items
    update_query = """
        UPDATE pronto_menu_items 
        SET is_quick_serve = true
        FROM pronto_menu_categories mc
        WHERE pronto_menu_items.category_id = mc.id
        AND mc.slug = ANY(%s)
        AND pronto_menu_items.is_quick_serve = false
    """
    cursor.execute(update_query, (quick_serve_categories,))

    return cursor.rowcount


def main():
    parser = argparse.ArgumentParser(description="Migrar productos a quick-serve")
    parser.add_argument(
        "--dry-run", action="store_true", help="Solo mostrar qué se actualizaría"
    )
    parser.add_argument("--yes", action="store_true", help="Confirmar automáticamente")

    args = parser.parse_args()

    print("╔═══════════════════════════════════════════════════════════╗")
    print("║                                                       ║")
    print("║   🚀 MIGRACIÓN DE PRODUCTOS QUICK-SERVE             ║")
    print("║                                                       ║")
    print("╚═══════════════════════════════════════════════════════════╝")
    print()

    # Connect to database
    print("🔗 Conectando a PostgreSQL...")
    try:
        conn = psycopg2.connect(
            host=postgres_host,
            port=postgres_port,
            user=postgres_user,
            password=postgres_password,
            database=postgres_db,
        )
        conn.autocommit = False
        cursor = conn.cursor()
        print("✅ Conectado a PostgreSQL")
    except Exception as e:
        print(f"❌ Error al conectar a PostgreSQL: {e}")
        sys.exit(1)

    try:
        # Perform migration
        updated_count = migrate_quick_serve_items(cursor, dry_run=args.dry_run)

        if not args.dry_run and updated_count > 0:
            if not args.yes:
                confirm = input(
                    f"¿Estás seguro de actualizar {updated_count} items? (s/N): "
                )
                if confirm.lower() != "s":
                    print("❌ Operación cancelada")
                    conn.rollback()
                    return

            conn.commit()
            print(f"✅ {updated_count} items actualizados exitosamente")
        elif args.dry_run:
            print("✅ Operación simulada completada")
        else:
            print("✅ No se requirieron actualizaciones")

    except Exception as e:
        print(f"❌ Error durante la migración: {e}")
        conn.rollback()
        sys.exit(1)
    finally:
        cursor.close()
        conn.close()


if __name__ == "__main__":
    main()
