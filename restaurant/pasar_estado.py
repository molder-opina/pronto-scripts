#!/usr/bin/env python3
"""Cambiar estado de orden en PRONTO.

Flujo válido: pending -> confirmed -> preparing -> ready -> served -> delivered -> paid
Cancelación: pending/confirmed/preparing/ready -> cancelled

Uso:
    python pasar_a_preparacion.py --id 123
    python pasar_a_listo.py --id 123
    python pasar_a_entregado.py --id 123

Args:
    --id: ID de la orden (requerido)
    --json: Salida en JSON
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from dotenv import load_dotenv
from pronto_shared.db import get_session
from pronto_shared.models import Order

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)

STATE_TRANSITIONS = {
    "pending": ["confirmed", "cancelled"],
    "confirmed": ["preparing", "cancelled"],
    "preparing": ["ready", "cancelled"],
    "ready": ["served", "cancelled"],
    "served": ["delivered", "cancelled"],
    "delivered": ["paid", "cancelled"],
    "paid": [],
    "cancelled": [],
}


def transition_order(order_id: int, new_status: str):
    with get_session() as session:
        order = session.query(Order).filter(Order.id == order_id).first()
        if not order:
            return False, f"Orden {order_id} no encontrada"

        current_status = order.workflow_status
        if current_status not in STATE_TRANSITIONS:
            return False, f"Estado '{current_status}' no válido"

        allowed = STATE_TRANSITIONS.get(current_status, [])
        if new_status not in allowed:
            return (
                False,
                f"No se puede pasar de '{current_status}' a '{new_status}'. Permitidos: {allowed}",
            )

        order.workflow_status = new_status
        from datetime import datetime

        order.updated_at = datetime.utcnow()
        session.commit()

        return True, f"Orden {order_id}: {current_status} -> {new_status}"


def main():
    parser = argparse.ArgumentParser(description="Cambiar estado de orden")
    parser.add_argument("--id", required=True, type=int, help="ID de la orden")
    parser.add_argument("--status", required=True, help="Nuevo estado")
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    success, message = transition_order(args.id, args.status)

    if args.json:
        import json

        if success:
            print(json.dumps({"status": "success", "message": message}))
        else:
            print(json.dumps({"status": "error", "message": message}))
            sys.exit(1)
    else:
        print(message)


if __name__ == "__main__":
    main()
