#!/usr/bin/env python3
"""
Script para aplicar la migración de realtime_events en Supabase/PostgreSQL.

Uso:
    python3 apply_realtime_events_migration.py
"""
import sys
from pathlib import Path

# Agregar el directorio build al path
sys.path.insert(0, str(Path(__file__).parent / "build"))

from sqlalchemy import text  # noqa: E402

from pronto_shared.config import load_config  # noqa: E402
from pronto_shared.db import init_engine  # noqa: E402
from pronto_shared.logging_config import get_logger  # noqa: E402

logger = get_logger(__name__)

# Initialize database connection
config = load_config("pronto-employees")
engine = init_engine(config)


def check_table_exists(table_name: str) -> bool:
    """Verifica si una tabla existe en el esquema public."""
    query = text(
        """
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = :table_name
    """
    )
    with engine.connect() as conn:
        result = conn.execute(query, {"table_name": table_name})
        count = result.scalar()
    return count > 0


def apply_migration():
    """Aplica la migración para crear la tabla realtime_events."""
    sql_path = Path(__file__).parent / "migrations" / "add_realtime_events_table.sql"
    if not sql_path.exists():
        print(f"\n❌ No se encontró el archivo SQL: {sql_path}")
        return 1

    try:
        logger.info("Iniciando migración de realtime_events...")

        if check_table_exists("realtime_events"):
            logger.warning("La tabla realtime_events ya existe. No se requieren cambios.")
            print("✅ La migración ya está aplicada")
            return 0

        sql_content = sql_path.read_text(encoding="utf-8")
        logger.info("Aplicando script SQL desde %s", sql_path)

        raw_conn = engine.raw_connection()
        try:
            cursor = raw_conn.cursor()
            cursor.execute(sql_content)
            raw_conn.commit()
        finally:
            raw_conn.close()

        logger.info("Migración completada exitosamente")
        print("\n✅ Migración aplicada exitosamente")
        print("Tabla creada: realtime_events")
        print("Índices: ix_realtime_event_type, ix_realtime_event_created_at")
        print("RLS y políticas configuradas")
        print("Función cleanup_old_realtime_events creada")
        return 0
    except Exception as e:
        logger.error("Error aplicando migración: %s", e)
        print(f"\n❌ Error aplicando migración: {e}")
        import traceback

        traceback.print_exc()
        return 1


def main():
    """Punto de entrada principal."""
    print("=== APLICAR MIGRACIÓN REALTIME EVENTS ===\n")
    return apply_migration()


if __name__ == "__main__":
    sys.exit(main())
