#!/usr/bin/env python3
"""
Script para aplicar la migración de entrega parcial a la base de datos.
Este script agrega los campos necesarios para el tracking de entrega parcial en order_items.

Uso:
    python3 apply_partial_delivery_migration.py
"""
import sys
from pathlib import Path

# Agregar el directorio build al path
sys.path.insert(0, str(Path(__file__).parent / "build"))

from sqlalchemy import text  # noqa: E402

from shared.config import load_config  # noqa: E402
from shared.db import get_session, init_engine  # noqa: E402
from shared.logging_config import get_logger  # noqa: E402

logger = get_logger(__name__)

# Initialize database connection
config = load_config("pronto-employees")
init_engine(config)


def check_column_exists(session, table_name: str, column_name: str) -> bool:
    """Verifica si una columna existe en una tabla."""
    query = text(
        """
        SELECT COUNT(*)
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = :table_name
        AND COLUMN_NAME = :column_name
    """
    )
    result = session.execute(query, {"table_name": table_name, "column_name": column_name})
    count = result.scalar()
    return count > 0


def apply_migration():
    """Aplica la migración para agregar campos de entrega parcial."""
    try:
        with get_session() as session:
            logger.info("Iniciando migración de entrega parcial...")

            # Verificar si la migración ya fue aplicada
            if check_column_exists(session, "order_items", "delivered_quantity"):
                logger.warning(
                    "La migración ya fue aplicada anteriormente. No se requieren cambios."
                )
                print("✅ La migración ya está aplicada")
                return 0

            logger.info("Aplicando migración...")

            # Agregar columna delivered_quantity
            session.execute(
                text(
                    """
                ALTER TABLE order_items
                ADD COLUMN delivered_quantity INTEGER NOT NULL DEFAULT 0
            """
                )
            )
            logger.info("✓ Columna delivered_quantity agregada")

            # Agregar columna is_fully_delivered
            session.execute(
                text(
                    """
                ALTER TABLE order_items
                ADD COLUMN is_fully_delivered BOOLEAN NOT NULL DEFAULT FALSE
            """
                )
            )
            logger.info("✓ Columna is_fully_delivered agregada")

            # Agregar columna delivered_at
            session.execute(
                text(
                    """
                ALTER TABLE order_items
                ADD COLUMN delivered_at TIMESTAMP NULL
            """
                )
            )
            logger.info("✓ Columna delivered_at agregada")

            # Agregar columna delivered_by_employee_id
            session.execute(
                text(
                    """
                ALTER TABLE order_items
                ADD COLUMN delivered_by_employee_id INTEGER NULL
            """
                )
            )
            logger.info("✓ Columna delivered_by_employee_id agregada")

            # Agregar foreign key constraint
            session.execute(
                text(
                    """
                ALTER TABLE order_items
                ADD CONSTRAINT fk_order_items_delivered_by
                    FOREIGN KEY (delivered_by_employee_id)
                    REFERENCES employees(id) ON DELETE SET NULL
            """
                )
            )
            logger.info("✓ Foreign key constraint agregado")

            # Agregar check constraint
            session.execute(
                text(
                    """
                ALTER TABLE order_items
                ADD CONSTRAINT chk_delivered_quantity_valid
                    CHECK (delivered_quantity >= 0 AND delivered_quantity <= quantity)
            """
                )
            )
            logger.info("✓ Check constraint agregado")

            # Agregar índice
            session.execute(
                text(
                    """
                CREATE INDEX ix_order_items_delivered
                ON order_items(is_fully_delivered, delivered_at)
            """
                )
            )
            logger.info("✓ Índice ix_order_items_delivered creado")

            session.commit()
            logger.info("Migración completada exitosamente")
            print("\n✅ Migración aplicada exitosamente")
            print("\nCampos agregados a order_items:")
            print("  - delivered_quantity (INTEGER, default 0)")
            print("  - is_fully_delivered (BOOLEAN, default FALSE)")
            print("  - delivered_at (TIMESTAMP, nullable)")
            print("  - delivered_by_employee_id (INTEGER, nullable)")
            print("\nConstraints agregados:")
            print("  - fk_order_items_delivered_by (FK a employees)")
            print("  - chk_delivered_quantity_valid (CHECK delivered_quantity <= quantity)")
            print("\nÍndices creados:")
            print("  - ix_order_items_delivered (is_fully_delivered, delivered_at)")

            return 0

    except Exception as e:
        logger.error(f"Error aplicando migración: {e}")
        print(f"\n❌ Error aplicando migración: {e}")
        import traceback

        traceback.print_exc()
        return 1


def rollback_migration():
    """Revierte la migración (solo para desarrollo/testing)."""
    try:
        with get_session() as session:
            logger.info("Revirtiendo migración de entrega parcial...")

            # Verificar si hay que revertir
            if not check_column_exists(session, "order_items", "delivered_quantity"):
                logger.warning("La migración no está aplicada. No hay nada que revertir.")
                print("⚠️ La migración no está aplicada")
                return 0

            # Advertencia
            print("\n⚠️  ADVERTENCIA: Esto eliminará los campos de entrega parcial")
            print("    y PERDERÁ TODOS LOS DATOS de entrega parcial.")
            response = input(
                "\n¿Está seguro de que desea continuar? (escriba 'SI' para confirmar): "
            )

            if response.strip().upper() != "SI":
                print("Operación cancelada")
                return 0

            logger.info("Revirtiendo cambios...")

            # Eliminar índice
            session.execute(text("DROP INDEX IF EXISTS ix_order_items_delivered ON order_items"))
            logger.info("✓ Índice eliminado")

            # Eliminar constraints
            session.execute(
                text(
                    """
                ALTER TABLE order_items
                DROP CONSTRAINT IF EXISTS chk_delivered_quantity_valid
            """
                )
            )
            logger.info("✓ Check constraint eliminado")

            session.execute(
                text(
                    """
                ALTER TABLE order_items
                DROP FOREIGN KEY IF EXISTS fk_order_items_delivered_by
            """
                )
            )
            logger.info("✓ Foreign key eliminado")

            # Eliminar columnas
            session.execute(
                text("ALTER TABLE order_items DROP COLUMN IF EXISTS delivered_by_employee_id")
            )
            session.execute(text("ALTER TABLE order_items DROP COLUMN IF EXISTS delivered_at"))
            session.execute(
                text("ALTER TABLE order_items DROP COLUMN IF EXISTS is_fully_delivered")
            )
            session.execute(
                text("ALTER TABLE order_items DROP COLUMN IF EXISTS delivered_quantity")
            )
            logger.info("✓ Columnas eliminadas")

            session.commit()
            logger.info("Migración revertida exitosamente")
            print("\n✅ Migración revertida exitosamente")
            return 0

    except Exception as e:
        logger.error(f"Error revirtiendo migración: {e}")
        print(f"\n❌ Error revirtiendo migración: {e}")
        import traceback

        traceback.print_exc()
        return 1


def main():
    """Punto de entrada principal."""
    if len(sys.argv) > 1 and sys.argv[1] == "--rollback":
        print("=== REVERTIR MIGRACIÓN DE ENTREGA PARCIAL ===\n")
        return rollback_migration()
    else:
        print("=== APLICAR MIGRACIÓN DE ENTREGA PARCIAL ===\n")
        return apply_migration()


if __name__ == "__main__":
    sys.exit(main())
