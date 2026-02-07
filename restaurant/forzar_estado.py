#!/usr/bin/env python3
"""Forzar estado de orden (admin only).

Úsar con precaución - rompe el flujo normal.

Uso:
    python forzar_estado.py --id 123 --status preparing
    python forzar_estado.py --id 123 --status pending --json

Args:
    --id: ID de la orden (requerido)
    --status: Estado forzado (requerido)
    --reason: Razón del cambio
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

ALL_STATUSES = [
    "pending",
    "confirmed",
    "preparing",
    "ready",
    "served",
    "delivered",
    "paid",
    "cancelled",
]


def main():
    parser = argparse.ArgumentParser(description="Forzar estado de orden (ADMIN)")
    parser.add_argument("--id", required=True, type=int, help="ID de la orden")
    parser.add_argument(
        "--status", required=True, help=f"Estado forzado: {', '.join(ALL_STATUSES)}"
    )
    parser.add_argument(
        "--reason", default="Cambio manual forzado", help="Razón del cambio"
    )
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    if args.status not in ALL_STATUSES:
        if args.json:
            print(
                json.dumps(
                    {"status": "error", "message": f"Estado inválido: {args.status}"}
                )
            )
        else:
            print(f"Error: Estado inválido. Usar: {', '.join(ALL_STATUSES)}")
        sys.exit(1)

    with get_session() as session:
        order = session.query(Order).filter(Order.id == args.id).first()
        if not order:
            if args.json:
                print(
                    json.dumps(
                        {"status": "error", "message": f"Orden {args.id} no encontrada"}
                    )
                )
            else:
                print(f"Error: Orden {args.id} no encontrada")
            sys.exit(1)

        old_status = order.workflow_status
        order.workflow_status = args.status
        order.updated_at = datetime.utcnow()
        session.commit()

        if args.json:
            print(
                json.dumps(
                    {
                        "status": "success",
                        "order_id": args.id,
                        "old_status": old_status,
                        "new_status": args.status,
                        "reason": args.reason,
                    }
                )
            )
        else:
            print(f"ORDEN {args.id}: {old_status} -> {args.status} (FORZADO)")
            print(f"Razón: {args.reason}")


if __name__ == "__main__":
    main()
