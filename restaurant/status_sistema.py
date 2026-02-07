#!/usr/bin/env python3
"""Verificar estado del sistema PRONTO.

Uso:
    python status_sistema.py
    python status_sistema.py --json

Verifica:
    - Conexión a PostgreSQL
    - Conexión a Redis
    - Estado de servicios
    - Contadores de registros
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from dotenv import load_dotenv

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)


def check_postgres():
    try:
        from pronto_shared.db import get_session

        with get_session() as session:
            result = session.execute("SELECT 1")
            return {"status": "connected", "message": "PostgreSQL OK"}
    except Exception as e:
        return {"status": "error", "message": str(e)}


def check_redis():
    try:
        import redis

        r = redis.Redis(host="localhost", port=6379, decode_responses=True)
        r.ping()
        return {"status": "connected", "message": "Redis OK"}
    except Exception as e:
        return {"status": "error", "message": str(e)}


def get_counts():
    try:
        from pronto_shared.db import get_session
        from pronto_shared.models import Order, Customer, MenuItem, Table, Employee

        with get_session() as session:
            counts = {
                "orders": session.query(Order).count(),
                "customers": session.query(Customer).count(),
                "products": session.query(MenuItem).count(),
                "tables": session.query(Table).count(),
                "employees": session.query(Employee).count(),
            }
            return counts
    except Exception as e:
        return {"error": str(e)}


def main():
    parser = argparse.ArgumentParser(description="Verificar estado del sistema PRONTO")
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    status = {
        "timestamp": datetime.utcnow().isoformat(),
        "postgres": check_postgres(),
        "redis": check_redis(),
        "counts": get_counts(),
    }

    if args.json:
        print(json.dumps(status, indent=2))
    else:
        print("=== ESTADO DEL SISTEMA PRONTO ===")
        print(f"Timestamp: {status['timestamp']}")
        print(
            f"PostgreSQL: {status['postgres']['status']} - {status['postgres']['message']}"
        )
        print(f"Redis: {status['redis']['status']} - {status['redis']['message']}")
        print("\n=== CONTADORES ===")
        for key, value in status["counts"].items():
            print(f"  {key}: {value}")


if __name__ == "__main__":
    from datetime import datetime

    main()
