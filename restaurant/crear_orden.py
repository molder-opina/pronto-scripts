#!/usr/bin/env python3
"""Crear orden en PRONTO.

Uso:
    python crear_orden.py --customer-id 1 --table-id 1 --employee-id 1
    python crear_orden.py --customer-id 1 --items '[{"menu_item_id": 1, "quantity": 2}]'

Args:
    --customer-id: ID del cliente (requerido)
    --table-id: ID de la mesa (opcional)
    --employee-id: ID del empleado (requerido)
    --items: JSON array con items [{menu_item_id, quantity, modifiers}]
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
from pronto_shared.models import Order, OrderItem
from sqlalchemy import text

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)


def main():
    parser = argparse.ArgumentParser(description="Crear orden en PRONTO")
    parser.add_argument("--customer-id", required=True, type=int, help="ID del cliente")
    parser.add_argument("--table-id", type=int, help="ID de la mesa")
    parser.add_argument(
        "--employee-id", required=True, type=int, help="ID del empleado"
    )
    parser.add_argument("--items", help="JSON array de items")
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    items_data = []
    if args.items:
        try:
            items_data = json.loads(args.items)
        except json.JSONDecodeError as e:
            if args.json:
                print(json.dumps({"status": "error", "message": f"Invalid JSON: {e}"}))
            else:
                print(f"Error: JSON inválido: {e}")
            sys.exit(1)

    with get_session() as session:
        order = Order(
            customer_id=args.customer_id,
            table_id=args.table_id,
            employee_id=args.employee_id,
            workflow_status="pending",
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
        )
        session.add(order)
        session.flush()

        total = Decimal("0.00")
        for item_data in items_data:
            menu_item_id = item_data.get("menu_item_id")
            quantity = item_data.get("quantity", 1)

            result = session.execute(
                text("SELECT price FROM pronto_menu_items WHERE id = :id"),
                {"id": menu_item_id},
            )
            price_row = result.fetchone()
            if not price_row:
                if args.json:
                    print(
                        json.dumps(
                            {
                                "status": "error",
                                "message": f"Menu item {menu_item_id} not found",
                            }
                        )
                    )
                else:
                    print(f"Error: Menu item {menu_item_id} no encontrado")
                sys.exit(1)

            price = price_row[0] or Decimal("0.00")
            item_total = price * quantity
            total += item_total

            order_item = OrderItem(
                order_id=order.id,
                menu_item_id=menu_item_id,
                quantity=quantity,
                unit_price=price,
                total_price=item_total,
            )
            session.add(order_item)

        order.total = total
        session.commit()
        session.refresh(order)

        if args.json:
            print(
                json.dumps(
                    {
                        "status": "success",
                        "order": {
                            "id": order.id,
                            "customer_id": order.customer_id,
                            "table_id": order.table_id,
                            "status": order.workflow_status,
                            "total": float(order.total),
                        },
                    }
                )
            )
        else:
            print(
                f"Orden creada: ID={order.id}, Status={order.workflow_status}, Total=${order.total}"
            )


if __name__ == "__main__":
    main()
