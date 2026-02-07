#!/usr/bin/env python3
"""Pagar orden en PRONTO (efectivo o tarjeta).

Uso:
    python pagar_orden.py --id 123 --method cash
    python pagar_orden.py --id 123 --method card --amount 150.50

Args:
    --id: ID de la orden (requerido)
    --method: cash | card
    --amount: Monto recibido (para efectivo, calcula cambio)
    --json: Salida en JSON
"""

import argparse
import json
import sys
from datetime import datetime
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from dotenv import load_dotenv
from pronto_shared.db import get_session
from pronto_shared.models import Order

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)


def main():
    parser = argparse.ArgumentParser(description="Pagar orden en PRONTO")
    parser.add_argument("--id", required=True, type=int, help="ID de la orden")
    parser.add_argument(
        "--method", required=True, choices=["cash", "card"], help="Método de pago"
    )
    parser.add_argument("--amount", type=float, help="Monto recibido (solo efectivo)")
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

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

        if order.workflow_status != "delivered":
            if args.json:
                print(
                    json.dumps(
                        {
                            "status": "error",
                            "message": f"La orden debe estar en 'delivered', está en '{order.workflow_status}'",
                        }
                    )
                )
            else:
                print(
                    f"Error: La orden debe estar en 'delivered' para pagar. Estado actual: {order.workflow_status}"
                )
            sys.exit(1)

        total = order.total or Decimal("0.00")
        change = Decimal("0.00")

        if args.method == "cash":
            if args.amount is None:
                if args.json:
                    print(
                        json.dumps(
                            {
                                "status": "error",
                                "message": "Monto requerido para pago en efectivo",
                            }
                        )
                    )
                else:
                    print("Error: Debe especificar --amount para pago en efectivo")
                sys.exit(1)
            received = Decimal(str(args.amount))
            if received < total:
                if args.json:
                    print(
                        json.dumps(
                            {
                                "status": "error",
                                "message": f"Monto insuficiente: ${received} < ${total}",
                            }
                        )
                    )
                else:
                    print(
                        f"Error: Monto insuficiente. Recibido: ${received}, Total: ${total}"
                    )
                sys.exit(1)
            change = received - total

        order.workflow_status = "paid"
        order.updated_at = datetime.utcnow()
        order.paid_at = datetime.utcnow()
        session.commit()

        if args.json:
            print(
                json.dumps(
                    {
                        "status": "success",
                        "order_id": order.id,
                        "payment_method": args.method,
                        "total": float(total),
                        "received": float(args.amount) if args.amount else None,
                        "change": float(change),
                    }
                )
            )
        else:
            print(f"ORDEN {order.id} PAGADA")
            print(f"  Método: {args.method}")
            print(f"  Total: ${total}")
            if args.method == "cash":
                print(f"  Recibido: ${args.amount}")
                print(f"  Cambio: ${change}")


if __name__ == "__main__":
    main()
