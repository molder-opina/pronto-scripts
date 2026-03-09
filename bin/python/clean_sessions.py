#!/usr/bin/env python3
"""
Script para limpiar sesiones de la base de datos.

Este script permite:
1. Limpiar sesiones cerradas (closed, paid, cancelled)
2. Limpiar TODAS las sesiones (con confirmación)
3. Mostrar estadísticas antes de limpiar

Uso:
    python3 bin/python/clean_sessions.py [--all] [--dry-run] [--yes]

Opciones:
    --all: Limpiar TODAS las sesiones (requiere confirmación)
    --dry-run: Solo mostrar qué se limpiaría, sin ejecutar
    --yes: Responder 'sí' automáticamente a todas las confirmaciones
"""

import argparse
import os
import sys
from datetime import datetime, timedelta, timezone
from urllib.parse import urlparse

try:
    import psycopg2
except ImportError:
    print("❌ Error: El paquete 'psycopg2-binary' no está instalado")
    print("   Para instalar: pip install psycopg2-binary")
    sys.exit(1)

try:
    from redis import Redis
except ImportError:
    print("⚠️  Advertencia: El paquete 'redis' no está instalado. No se limpiará Redis.")
    print("   Para instalar: pip install redis")
    Redis = None

# Load database configuration from environment
postgres_host = os.getenv("POSTGRES_HOST", "localhost")
postgres_port = os.getenv("POSTGRES_PORT", "5432")
postgres_user = os.getenv("POSTGRES_USER", "pronto")
postgres_password = os.getenv("POSTGRES_PASSWORD", "pronto123")
postgres_db = os.getenv("POSTGRES_DB", "pronto")
redis_url = os.getenv("REDIS_URL", "")
redis_host = os.getenv("REDIS_HOST", "localhost")
redis_port = int(os.getenv("REDIS_PORT", "6379"))
redis_password = os.getenv("REDIS_PASSWORD", "")
redis_db = int(os.getenv("REDIS_DB", "0"))


def get_redis_connection_kwargs():
    """Construir parámetros de conexión Redis desde REDIS_URL o variables separadas."""
    if redis_url:
        parsed = urlparse(redis_url)
        host = parsed.hostname or redis_host
        port = parsed.port or redis_port
        password = parsed.password or redis_password or None
        db = redis_db
        if parsed.path and parsed.path != "/":
            try:
                db = int(parsed.path.lstrip("/"))
            except ValueError:
                db = redis_db
        return {
            "host": host,
            "port": port,
            "password": password,
            "db": db,
            "decode_responses": True,
        }

    return {
        "host": redis_host,
        "port": redis_port,
        "password": redis_password or None,
        "db": redis_db,
        "decode_responses": True,
    }


def get_redis_display_url():
    kwargs = get_redis_connection_kwargs()
    return f"redis://{kwargs['host']}:{kwargs['port']}/{kwargs['db']}"

print("📊 Configuración de BD:")
print(f"   Host: {postgres_host}:{postgres_port}")
print(f"   Usuario: {postgres_user}")
print(f"   Base de datos: {postgres_db}")
print(f"   Redis: {get_redis_display_url()}")
print()


def clean_redis(dry_run=False):
    """Limpiar claves de Redis."""
    if not Redis:
        return 0

    try:
        r = Redis(**get_redis_connection_kwargs())
        # Scan for keys to delete
        keys_to_delete = []
        for match in r.scan_iter("pronto:*"):
            keys_to_delete.append(match)

        # Also clean session keys if they exist (depending on config)
        for match in r.scan_iter("session:*"):
            keys_to_delete.append(match)

        print(f"📊 Claves de Redis encontradas: {len(keys_to_delete)}")

        if dry_run:
            print("🔍 Modo dry-run: No se eliminarán claves de Redis")
            return 0

        if keys_to_delete:
            count = r.delete(*keys_to_delete)
            print(f"  🗑️  Eliminadas {count} claves de Redis")
            return count
        return 0

    except Exception as e:
        print(f"⚠️  Error al limpiar Redis: {e}")
        return 0


def get_session_stats(cursor):
    """Obtener estadísticas de sesiones."""
    # Total de sesiones
    cursor.execute("SELECT COUNT(*) FROM pronto_dining_sessions")
    total_sessions = cursor.fetchone()[0]

    # Conteo por status
    cursor.execute(
        """
        SELECT status, COUNT(*)
        FROM pronto_dining_sessions
        GROUP BY status
    """
    )
    status_counts = dict(cursor.fetchall())

    # Sesiones antiguas (más de 24 horas)
    one_day_ago = datetime.now(timezone.utc) - timedelta(days=1)
    cursor.execute(
        """
        SELECT COUNT(*)
        FROM pronto_dining_sessions
        WHERE opened_at < %s
    """,
        (one_day_ago,),
    )
    old_sessions = cursor.fetchone()[0]

    return {"total": total_sessions, "by_status": status_counts, "old": old_sessions}


def clean_closed_sessions(cursor, conn, dry_run=False):
    """Limpiar sesiones cerradas."""
    cursor.execute(
        """
        SELECT id, table_number
        FROM pronto_dining_sessions
        WHERE status IN ('closed', 'paid', 'cancelled')
    """
    )
    sessions_to_delete = cursor.fetchall()

    print(f"📊 Sesiones cerradas encontradas: {len(sessions_to_delete)}")

    if dry_run:
        print("🔍 Modo dry-run: No se eliminarán sesiones")
        return 0

    deleted_count = 0
    for session_id, table_number in sessions_to_delete:
        # Contar órdenes asociadas
        cursor.execute(
            "SELECT COUNT(*) FROM pronto_orders WHERE session_id = %s", (session_id,)
        )
        orders_count = cursor.fetchone()[0]

        # Eliminar registros dependientes en orden correcto (FK constraints)
        cursor.execute(
            "DELETE FROM pronto_feedback WHERE session_id = %s", (session_id,)
        )
        cursor.execute("DELETE FROM pronto_orders WHERE session_id = %s", (session_id,))

        # Eliminar sesión
        cursor.execute(
            "DELETE FROM pronto_dining_sessions WHERE id = %s", (session_id,)
        )

        deleted_count += 1
        print(
            f"  🗑️  Eliminada sesión {session_id} (mesa {table_number}) - {orders_count} órdenes"
        )

    conn.commit()
    return deleted_count


def clean_all_sessions(cursor, conn, dry_run=False):
    """Limpiar TODAS las sesiones."""
    cursor.execute("SELECT id, table_number FROM pronto_dining_sessions")
    all_sessions = cursor.fetchall()

    print(f"📊 TODAS las sesiones encontradas: {len(all_sessions)}")

    if dry_run:
        print("🔍 Modo dry-run: No se eliminarán sesiones")
        return 0

    deleted_count = 0
    for session_id, table_number in all_sessions:
        # Contar órdenes asociadas
        cursor.execute(
            "SELECT COUNT(*) FROM pronto_orders WHERE session_id = %s", (session_id,)
        )
        orders_count = cursor.fetchone()[0]

        # Eliminar registros dependientes en orden correcto (FK constraints)
        cursor.execute(
            "DELETE FROM pronto_feedback WHERE session_id = %s", (session_id,)
        )
        cursor.execute("DELETE FROM pronto_orders WHERE session_id = %s", (session_id,))

        # Eliminar sesión
        cursor.execute(
            "DELETE FROM pronto_dining_sessions WHERE id = %s", (session_id,)
        )

        deleted_count += 1
        print(
            f"  🗑️  Eliminada sesión {session_id} (mesa {table_number}) - {orders_count} órdenes"
        )

    conn.commit()
    return deleted_count


def main():
    parser = argparse.ArgumentParser(description="Limpiar sesiones de la base de datos")
    parser.add_argument("--all", action="store_true", help="Limpiar TODAS las sesiones")
    parser.add_argument(
        "--dry-run", action="store_true", help="Solo mostrar qué se limpiaría"
    )
    parser.add_argument(
        "--yes", action="store_true", help="Responder sí automáticamente"
    )

    args = parser.parse_args()

    print("╔═══════════════════════════════════════════════════════════╗")
    print("║                                                       ║")
    print("║   🧹 LIMPIEZA DE SESIONES 🧹                      ║")
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
        stats = get_session_stats(cursor)
        print("📊 Estadísticas actuales:")
        print(f"   Total de sesiones: {stats['total']}")
        for status, count in stats["by_status"].items():
            print(f"   {status}: {count}")
        print(f"   Sesiones antiguas (>24h): {stats['old']}")
        print()

        if args.all:
            print("⚠️  MODO PELIGROSO: Se limpiarán TODAS las sesiones")
            if not args.yes and not args.dry_run:
                confirm = input("¿Estás seguro? (escribe 'yes' para confirmar): ")
                if confirm.lower() != "yes":
                    print("❌ Operación cancelada")
                    return

            deleted = clean_all_sessions(cursor, conn, args.dry_run)
            action = "mostradas" if args.dry_run else "eliminadas"
            print(f"✅ {deleted} sesiones {action}")

            # Redis cleanup for --all
            print("🧹 Limpiando Redis...")
            clean_redis(args.dry_run)
        else:
            print("🧹 Limpiando sesiones cerradas...")
            deleted = clean_closed_sessions(cursor, conn, args.dry_run)
            action = "mostradas" if args.dry_run else "eliminadas"
            print(f"✅ {deleted} sesiones {action}")
            # Redis cleanup is typically full flush or specific keys, tricky for partial.
            # We'll skip Redis for partial clean to avoid deleting active session data.

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
