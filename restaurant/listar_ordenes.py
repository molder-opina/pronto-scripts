#!/usr/bin/env python3
"""Listar órdenes en PRONTO.

Uso:
    python listar_ordenes.py
    python listar_ordenes.py --status pending
    python listar_ordenes.py --status pending,preparing --json

Args:
    --status: Filtrar por estado(s), separados por coma
    --include-closed: Incluir órdenes cerradas
    --customer-id: Filtrar por cliente
    --json: Salida en JSON
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from dotenv import load_dotenv
from pronto_shared.db import get_session
from pronto_shared.models import Order

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)


OPEN_STATUSES = ["pending", "confirmed", "preparing", "ready", "served", "delivered"]
CLOSED_STATUSES = ["paid", "cancelled"]

ALL_STATUSES = OPEN_STATUSES + CLOSED_STATUSES


def main():
    parser = argparse.ArgumentParser(description="Listar órdenes en PRONTO")
    parser.add_argument(
        "--status", help="Filtrar por estado(s), ej: 'pending,preparing'"
    )
    parser.add_argument(
        "--include-closed", action="store_true", help="Incluir órdenes cerradas"
    )
    parser.add_argument("--customer-id", type=int, help="Filtrar por cliente")
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    with get_session() as session:
        query = session.query(Order)

        if args.status:
            statuses = [s.strip() for s in args.status.split(",")]
            query = query.filter(Order.workflow_status.in_(statuses))
        elif not args.include_closed:
            query = query.filter(Order.workflow_status.in_(OPEN_STATUSES))

        if args.customer_id:
            query = query.filter(Order.customer_id == args.customer_id)

        orders = query.order_by(Order.created_at.desc()).limit(100).all()

        if args.json:
            print(
                json.dumps(
                    {
                        "status": "success",
                        "count": len(orders),
                        "orders": [
                            {
                                "id": o.id,
                                "customer_id": o.customer_id,
                                "table_id": o.table_id,
                                "status": o.workflow_status,
                                "total": float(o.total) if o.total else 0,
                                "created_at": o.created_at.isoformat()
                                if o.created_at
                                else None,
                            }
                            for o in orders
                        ],
                    }
                )
            )
        else:
            print(
                f"{'ID':<5} {'STATUS':<12} {'CLIENTE':<8} {'MESA':<5} {'TOTAL':<10} {'FECHA'}"
            )
            print("-" * 60)
            for o in orders:
                total = f"${o.total}" if o.total else "$0.00"
                fecha = o.created_at.strftime("%H:%M") if o.created_at else "-"
                print(
                    f"{o.id:<5} {o.workflow_status:<12} {o.customer_id:<8} {o.table_id or '-':<5} {total:<10} {fecha}"
                )


if __name__ == "__main__":
    main()
