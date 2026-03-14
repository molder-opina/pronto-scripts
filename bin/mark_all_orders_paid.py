#!/usr/bin/env python3
"""
Script para marcar todas las órdenes activas como pagadas.

Este script actualiza directamente en la base de datos todas las órdenes
con estados no terminales (new, queued, preparing, ready, delivered, awaiting_payment)
al estado terminal 'paid'.

Uso:
    python3 bin/mark-all-orders-paid.py [--dry-run] [--confirm]

Opciones:
    --dry-run: Solo mostrar qué se actualizaría, sin ejecutar
    --confirm: Confirmar automáticamente sin preguntar
"""

import argparse
import os
import sys
from datetime import datetime, timezone

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

NON_TERMINAL_STATUSES = [
    "new",
    "queued",
    "preparing",
    "ready",
    "delivered",
    "awaiting_payment",
]


def get_orders_to_update(cursor):
    """Obtener órdenes con estados no terminales."""
    query = """
        SELECT id, workflow_status, total_amount, created_at
        FROM pronto_orders 
        WHERE workflow_status = ANY(%s)
        ORDER BY created_at DESC
    """
    cursor.execute(query, (NON_TERMINAL_STATUSES,))
    return cursor.fetchall()


def update_orders_to_paid(cursor, orders, dry_run=False):
    """Actualizar órdenes a estado 'paid'."""
    if not orders:
        print("✅ No hay órdenes para actualizar")
        return 0

    updated_count = 0
    current_time = datetime.now(timezone.utc)

    for order_id, status, total_amount, created_at in orders:
        if not dry_run:
            # Actualizar el estado de la orden
            cursor.execute(
                "UPDATE pronto_orders SET workflow_status = 'paid', updated_at = %s WHERE id = %s",
                (current_time, order_id),
            )

            # Agregar entrada al historial de estados
            cursor.execute(
                """
                INSERT INTO pronto_order_status_history (order_id, status, changed_at, changed_by)
                VALUES (%s, 'paid', %s, NULL)
                """,
                (order_id, current_time),
            )

        print(f"  ✅ Orden {order_id} ({status}) -> paid - ${total_amount}")
        updated_count += 1

    return updated_count


def main():
    parser = argparse.ArgumentParser(
        description="Marcar todas las órdenes activas como pagadas"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Solo mostrar qué se actualizaría"
    )
    parser.add_argument(
        "--confirm", action="store_true", help="Confirmar automáticamente"
    )

    args = parser.parse_args()

    print("╔═══════════════════════════════════════════════════════════╗")
    print("║                                                       ║")
    print("║   💰 MARCAR ÓRDENES COMO PAGADAS 💰                ║")
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
        # Obtener órdenes a actualizar
        orders_to_update = get_orders_to_update(cursor)

        if not orders_to_update:
            print("✅ No hay órdenes activas para marcar como pagadas")
            return

        print(f"📊 Órdenes activas encontradas: {len(orders_to_update)}")
        status_counts = {}
        total_amount = 0

        for order_id, status, amount, created_at in orders_to_update:
            status_counts[status] = status_counts.get(status, 0) + 1
            total_amount += amount or 0

        print("📋 Desglose por estado:")
        for status, count in sorted(status_counts.items()):
            print(f"   {status}: {count}")
        print(f"💰 Monto total: ${total_amount:.2f}")
        print()

        if not args.dry_run:
            if not args.confirm:
                confirm = input(
                    "¿Estás seguro de marcar estas órdenes como pagadas? (s/N): "
                )
                if confirm.lower() != "s":
                    print("❌ Operación cancelada")
                    return

            print("🔄 Actualizando órdenes...")
            updated_count = update_orders_to_paid(
                cursor, orders_to_update, dry_run=False
            )
            conn.commit()
            print(f"✅ {updated_count} órdenes actualizadas a 'paid'")
        else:
            print("🔍 Modo dry-run: Mostrando órdenes que se actualizarían...")
            update_orders_to_paid(cursor, orders_to_update, dry_run=True)
            print("✅ Operación simulada completada")

        print()
        print("🎉 ¡Todas las órdenes han sido marcadas como pagadas!")

    except Exception as e:
        print(f"❌ Error durante la actualización: {e}")
        conn.rollback()
        sys.exit(1)
    finally:
        cursor.close()
        conn.close()


if __name__ == "__main__":
    main()
