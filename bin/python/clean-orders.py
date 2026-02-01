#!/usr/bin/env python3
"""
Script para limpiar órdenes de la base de datos.

Este script permite:
1. Limpiar órdenes canceladas y entregadas
2. Limpiar TODAS las órdenes (con confirmación)
3. Mostrar estadísticas antes de limpiar
4. Filtrar por edad de las órdenes

Uso:
    python3 bin/python/clean-orders.py [--all] [--dry-run] [--yes] [--older-than DAYS]

Opciones:
    --all: Limpiar TODAS las órdenes (requiere confirmación)
    --dry-run: Solo mostrar qué se limpiaría, sin ejecutar
    --yes: Responder 'sí' automáticamente a todas las confirmaciones
    --older-than DAYS: Solo limpiar órdenes más antiguas que DAYS días
"""

import argparse
import os
import sys
from datetime import datetime, timedelta

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

print("📊 Configuración de BD:")
print(f"   Host: {postgres_host}:{postgres_port}")
print(f"   Usuario: {postgres_user}")
print(f"   Base de datos: {postgres_db}")
print()


def get_order_stats(cursor, older_than_days=None):
    """Obtener estadísticas de órdenes."""
    query = "SELECT workflow_status, COUNT(*) FROM pronto_orders"
    params = []

    if older_than_days:
        cutoff_date = datetime.utcnow() - timedelta(days=older_than_days)
        query += " WHERE created_at < %s"
        params.append(cutoff_date)

    query += " GROUP BY workflow_status"

    cursor.execute(query, params)
    status_counts = dict(cursor.fetchall())

    # Total de órdenes
    total_query = "SELECT COUNT(*) FROM pronto_orders"
    total_params = []
    if older_than_days:
        cutoff_date = datetime.utcnow() - timedelta(days=older_than_days)
        total_query += " WHERE created_at < %s"
        total_params.append(cutoff_date)

    cursor.execute(total_query, total_params)
    total_orders = cursor.fetchone()[0]

    # Órdenes con items (contar órdenes que tienen items en order_items)
    items_query = """
        SELECT COUNT(DISTINCT o.id)
        FROM pronto_orders o
        JOIN pronto_order_items oi ON o.id = oi.order_id
    """
    items_params = []
    if older_than_days:
        cutoff_date = datetime.utcnow() - timedelta(days=older_than_days)
        items_query += " WHERE o.created_at < %s"
        items_params.append(cutoff_date)

    cursor.execute(items_query, items_params)
    orders_with_items = cursor.fetchone()[0]

    return {"total": total_orders, "by_status": status_counts, "with_items": orders_with_items}


def clean_completed_orders(cursor, conn, dry_run=False, older_than_days=None):
    """Limpiar órdenes completadas (entregadas o canceladas)."""
    query = """
        SELECT id, workflow_status, total_amount
        FROM pronto_orders
        WHERE workflow_status IN ('delivered', 'cancelled')
    """
    params = []

    if older_than_days:
        cutoff_date = datetime.utcnow() - timedelta(days=older_than_days)
        query += " AND created_at < %s"
        params.append(cutoff_date)

    cursor.execute(query, params)
    orders_to_delete = cursor.fetchall()

    filter_msg = (
        f" (filtradas por órdenes más antiguas que {older_than_days} días)"
        if older_than_days
        else ""
    )
    print(f"📊 Órdenes completadas encontradas: {len(orders_to_delete)}{filter_msg}")

    if dry_run:
        print("🔍 Modo dry-run: No se eliminarán órdenes")
        return 0

    deleted_count = 0
    for order_id, status, total_amount in orders_to_delete:
        # Eliminar datos relacionados en orden correcto
        cursor.execute("DELETE FROM pronto_order_status_history WHERE order_id = %s", (order_id,))
        cursor.execute("DELETE FROM pronto_order_modifications WHERE order_id = %s", (order_id,))
        cursor.execute(
            """
            DELETE FROM pronto_order_item_modifiers
            WHERE order_item_id IN (
                SELECT id FROM pronto_order_items WHERE order_id = %s
            )
        """,
            (order_id,),
        )
        cursor.execute("DELETE FROM pronto_order_items WHERE order_id = %s", (order_id,))
        cursor.execute("DELETE FROM pronto_orders WHERE id = %s", (order_id,))

        deleted_count += 1
        print(f"  🗑️  Eliminada orden {order_id} ({status}) - ${total_amount}")

    conn.commit()
    return deleted_count


def clean_all_orders(cursor, conn, dry_run=False, older_than_days=None):
    """Limpiar TODAS las órdenes."""
    query = "SELECT id, workflow_status, total_amount FROM pronto_orders"
    params = []

    if older_than_days:
        cutoff_date = datetime.utcnow() - timedelta(days=older_than_days)
        query += " WHERE created_at < %s"
        params.append(cutoff_date)

    cursor.execute(query, params)
    all_orders = cursor.fetchall()

    filter_msg = (
        f" (filtradas por órdenes más antiguas que {older_than_days} días)"
        if older_than_days
        else ""
    )
    print(f"📊 TODAS las órdenes encontradas: {len(all_orders)}{filter_msg}")

    if dry_run:
        print("🔍 Modo dry-run: No se eliminarán órdenes")
        return 0

    deleted_count = 0
    for order_id, status, total_amount in all_orders:
        # Eliminar datos relacionados en orden correcto
        cursor.execute("DELETE FROM pronto_order_status_history WHERE order_id = %s", (order_id,))
        cursor.execute("DELETE FROM pronto_order_modifications WHERE order_id = %s", (order_id,))
        cursor.execute(
            """
            DELETE FROM pronto_order_item_modifiers
            WHERE order_item_id IN (
                SELECT id FROM pronto_order_items WHERE order_id = %s
            )
        """,
            (order_id,),
        )
        cursor.execute("DELETE FROM pronto_order_items WHERE order_id = %s", (order_id,))
        cursor.execute("DELETE FROM pronto_orders WHERE id = %s", (order_id,))

        deleted_count += 1
        print(f"  🗑️  Eliminada orden {order_id} ({status}) - ${total_amount}")

    conn.commit()
    return deleted_count


def main():
    parser = argparse.ArgumentParser(description="Limpiar órdenes de la base de datos")
    parser.add_argument("--all", action="store_true", help="Limpiar TODAS las órdenes")
    parser.add_argument("--dry-run", action="store_true", help="Solo mostrar qué se limpiaría")
    parser.add_argument("--yes", action="store_true", help="Responder sí automáticamente")
    parser.add_argument(
        "--older-than",
        type=int,
        metavar="DAYS",
        help="Solo limpiar órdenes más antiguas que DAYS días",
    )

    args = parser.parse_args()

    print("╔═══════════════════════════════════════════════════════════╗")
    print("║                                                       ║")
    print("║   🧹 LIMPIEZA DE ÓRDENES 🧹                       ║")
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
        conn.autocommit = False  # We'll manage transactions
        cursor = conn.cursor()
        print("✅ Conectado a PostgreSQL")
    except Exception as e:
        print(f"❌ Error al conectar a PostgreSQL: {e}")
        sys.exit(1)

    try:
        # Mostrar estadísticas iniciales
        stats = get_order_stats(cursor, args.older_than)
        print("📊 Estadísticas actuales:")
        print(f"   Total de órdenes: {stats['total']}")
        for status, count in stats["by_status"].items():
            print(f"   {status}: {count}")
        print(f"   Órdenes con items: {stats['with_items']}")
        if args.older_than:
            print(f"   Filtro aplicado: órdenes más antiguas que {args.older_than} días")
        print()

        if args.all:
            print("⚠️  MODO PELIGROSO: Se limpiarán TODAS las órdenes")
            if not args.yes and not args.dry_run:
                confirm = input("¿Estás seguro? (escribe 'yes' para confirmar): ")
                if confirm.lower() != "yes":
                    print("❌ Operación cancelada")
                    return

            deleted = clean_all_orders(cursor, conn, args.dry_run, args.older_than)
            action = "mostradas" if args.dry_run else "eliminadas"
            print(f"✅ {deleted} órdenes {action}")
        else:
            print("🧹 Limpiando órdenes completadas...")
            deleted = clean_completed_orders(cursor, conn, args.dry_run, args.older_than)
            action = "mostradas" if args.dry_run else "eliminadas"
            print(f"✅ {deleted} órdenes {action}")

        print()
        print("🎉 Limpieza completada!")

    except Exception as e:
        print(f"❌ Error durante la limpieza: {e}")
        conn.rollback()
        sys.exit(1)
    finally:
        cursor.close()
        conn.close()


if __name__ == "__main__":
    main()
