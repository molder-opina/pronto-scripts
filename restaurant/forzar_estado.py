#!/usr/bin/env python3
"""Transición administrativa de estado usando reglas canónicas.

Nota: este script ya no hace asignaciones directas de estado.
Si una transición no está permitida por policy, retorna error.

Uso:
    python forzar_estado.py --id <order_uuid|order_number> --status preparing
"""

from __future__ import annotations

import argparse
import json
import sys
import uuid
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

CANON_STATUSES = [status.value for status in OrderStatus]


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
    parser = argparse.ArgumentParser(description="Transición administrativa de estado")
    parser.add_argument("--id", required=True, help="UUID u order_number de la orden")
    parser.add_argument("--status", required=True, choices=CANON_STATUSES, help="Estado destino")
    parser.add_argument("--reason", default="Cambio manual administrativo", help="Razón")
    parser.add_argument("--actor-id", help="UUID de actor system/admin (opcional)")
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    try:
        actor_id = _parse_uuid(args.actor_id, "actor_id", required=False)
        target_status = OrderStatus(args.status)
    except ValueError as exc:
        _print_error(args.json, str(exc))
        sys.exit(1)

    with get_session() as db_session:
        order = _resolve_order(db_session, args.id)
        if order is None:
            _print_error(args.json, f"Orden no encontrada: {args.id}")
            sys.exit(1)

        order_id = order.id
        old_status = order.workflow_status

    payload = {"justification": args.reason}
    response, status_code = transition_order(
        order_id=order_id,
        to_status=target_status,
        actor_scope="system",
        actor_id=actor_id,
        payload=payload,
    )

    status_int = int(status_code)
    if status_int >= HTTPStatus.BAD_REQUEST:
        message = (
            response.get("error")
            or response.get("message")
            or response.get("detail")
            or f"No se pudo aplicar transición (status={status_int})"
        )
        _print_error(args.json, str(message))
        sys.exit(1)

    with get_session() as db_session:
        refreshed_order = db_session.get(Order, order_id)
        new_status = refreshed_order.workflow_status if refreshed_order else target_status.value

    if args.json:
        print(
            json.dumps(
                {
                    "status": "success",
                    "order_id": str(order_id),
                    "old_status": old_status,
                    "new_status": new_status,
                    "reason": args.reason,
                }
            )
        )
    else:
        print(f"ORDEN {order_id}: {old_status} -> {new_status}")
        print(f"Razón: {args.reason}")


if __name__ == "__main__":
    main()
