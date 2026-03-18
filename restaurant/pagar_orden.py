#!/usr/bin/env python3
"""Pagar orden en PRONTO con transición canónica a `paid`.

Uso:
    python pagar_orden.py --id <order_uuid|order_number> --method cash --amount 150.50
    python pagar_orden.py --id <order_uuid|order_number> --method card --reference TXN123
"""

from __future__ import annotations

import argparse
import json
import sys
import uuid
from decimal import Decimal
from http import HTTPStatus
from pathlib import Path

from sqlalchemy import select

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from dotenv import load_dotenv
from pronto_shared.constants import OrderStatus
from pronto_shared.db import get_session
from pronto_shared.models import Order
from pronto_shared.services.order_transitions import transition_order

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)


def _resolve_order(db_session, raw_identifier: str) -> Order | None:
    normalized = str(raw_identifier or "").strip()
    if not normalized:
        return None

    try:
        parsed_uuid: uuid.UUID | None = uuid.UUID(normalized)
    except ValueError:
        parsed_uuid = None

    if parsed_uuid is not None:
        order = db_session.get(Order, parsed_uuid)
        if order is not None:
            return order

    if normalized.isdigit():
        return (
            db_session.execute(
                select(Order).where(Order.order_number == int(normalized))
            )
            .scalars()
            .first()
        )

    return None


def _parse_uuid(raw_value: object, field_name: str, required: bool = True) -> uuid.UUID | None:
    value = str(raw_value or "").strip()
    if not value:
        if required:
            raise ValueError(f"{field_name} es requerido")
        return None
    try:
        return uuid.UUID(value)
    except ValueError as exc:
        raise ValueError(f"{field_name} inválido: {value}") from exc


def _print_error(as_json: bool, message: str) -> None:
    if as_json:
        print(json.dumps({"status": "error", "message": message}))
    else:
        print(f"Error: {message}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Pagar orden en PRONTO")
    parser.add_argument("--id", required=True, help="UUID u order_number de la orden")
    parser.add_argument(
        "--method",
        required=True,
        choices=["cash", "card", "stripe", "clip"],
        help="Método de pago",
    )
    parser.add_argument("--amount", type=float, help="Monto recibido (solo efectivo)")
    parser.add_argument("--reference", help="Referencia de pago")
    parser.add_argument(
        "--actor-scope",
        default="cashier",
        choices=["waiter", "cashier", "admin", "system"],
        help="Scope ejecutando el pago",
    )
    parser.add_argument("--actor-id", help="UUID del actor (opcional)")
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    if args.method == "cash" and args.amount is None:
        _print_error(args.json, "Debe especificar --amount para pago en efectivo")
        sys.exit(1)

    try:
        actor_id = _parse_uuid(args.actor_id, "actor_id", required=False)
    except ValueError as exc:
        _print_error(args.json, str(exc))
        sys.exit(1)

    with get_session() as db_session:
        order = _resolve_order(db_session, args.id)
        if order is None:
            _print_error(args.json, f"Orden no encontrada: {args.id}")
            sys.exit(1)

        order_id = order.id
        total = Decimal(str(order.total_amount or 0))
        current_status = order.workflow_status

    payload: dict[str, object] = {"payment_method": args.method}
    if args.reference:
        payload["payment_reference"] = args.reference
    if args.amount is not None:
        payload["amount_received"] = args.amount

    response, status_code = transition_order(
        order_id=order_id,
        to_status=OrderStatus.PAID,
        actor_scope=args.actor_scope,
        actor_id=actor_id,
        payload=payload,
    )

    status_int = int(status_code)
    if status_int >= HTTPStatus.BAD_REQUEST:
        message = (
            response.get("error")
            or response.get("message")
            or response.get("detail")
            or f"Error de pago (status={status_int})"
        )
        _print_error(args.json, str(message))
        sys.exit(1)

    change = Decimal("0.00")
    if args.method == "cash" and args.amount is not None:
        received = Decimal(str(args.amount))
        change = received - total

    if args.json:
        print(
            json.dumps(
                {
                    "status": "success",
                    "order_id": str(order_id),
                    "previous_status": current_status,
                    "new_status": OrderStatus.PAID.value,
                    "payment_method": args.method,
                    "total": float(total),
                    "received": float(args.amount) if args.amount is not None else None,
                    "change": float(change),
                }
            )
        )
    else:
        print(f"ORDEN {order_id} PAGADA")
        print(f"  Estado previo: {current_status}")
        print(f"  Método: {args.method}")
        print(f"  Total: ${float(total):.2f}")
        if args.method == "cash" and args.amount is not None:
            print(f"  Recibido: ${args.amount:.2f}")
            print(f"  Cambio: ${float(change):.2f}")


if __name__ == "__main__":
    main()
