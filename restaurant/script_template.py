#!/usr/bin/env python3
"""
Script Template para Operaciones de Negocio PRONTO

Este template debe usarse para todos los scripts en pronto-scripts/restaurant/

Uso:
    python script.py --help

Categorías:
    - Productos: crear_producto.py, eliminar_producto.py, modificar_producto.py
    - Órdenes: crear_orden.py, eliminar_orden.py, modificar_orden.py
    - Estados: pasar_a_preparacion.py, forzar_estado.py
    - Pagos: pagar_efectivo.py, pagar_tarjeta.py
    - Mesas: crear_mesa.py, asignar_mesa.py
"""

import argparse
import sys
import os
from datetime import datetime
from pathlib import Path

# Add parent directories to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from dotenv import load_dotenv

# Cargar configuración
ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)


def get_db_connection():
    """Obtener conexión a la base de datos."""
    import psycopg2

    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        database=os.getenv("DB_NAME", "pronto"),
        user=os.getenv("DB_USER", "pronto"),
        password=os.getenv("DB_PASSWORD", "pronto"),
    )


def get_redis_connection():
    """Obtener cliente de Redis."""
    import redis

    return redis.Redis(
        host=os.getenv("REDIS_HOST", "localhost"),
        port=os.getenv("REDIS_PORT", "6379"),
        decode_responses=True,
    )


def main():
    parser = argparse.ArgumentParser(
        description="Operación de negocio PRONTO",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
    python script.py --id 123
    python script.py --all
    python script.py --search "hamburguesa"
        """,
    )

    # Argumentos comunes
    parser.add_argument("--id", type=int, help="ID del registro")
    parser.add_argument("--all", action="store_true", help="Listar todos")
    parser.add_argument("--json", action="store_true", help="Salida en formato JSON")
    parser.add_argument("--verbose", "-v", action="store_true", help="Modo verbose")

    # Arguments específicos se agregan en cada script

    args = parser.parse_args()

    if args.verbose:
        print(f"[{datetime.now().isoformat()}] Iniciando script...")

    # Implementar lógica del script

    if args.json:
        import json

        print(json.dumps({"status": "success"}))
    else:
        print("Operación completada")


if __name__ == "__main__":
    main()
