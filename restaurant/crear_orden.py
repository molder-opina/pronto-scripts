#!/usr/bin/env python3
"""Crear orden en PRONTO usando el modelo canónico de estados.

Uso:
    python crear_orden.py --customer-id <uuid> --session-id <uuid> --employee-id <uuid>
    python crear_orden.py --customer-id <uuid> --table-id <uuid> --items '[{"menu_item_id": "<uuid>", "quantity": 2}]'

Reglas:
- La orden nace en `new`.
- Si se pasa `--employee-id`, se intenta transición canónica a `queued`.
- Si todos los items son quick-serve y la orden está en `queued`, avanza a `ready`.
"""

from __future__ import annotations

import argparse
import json
import sys
import uuid
from decimal import Decimal
from pathlib import Path

from sqlalchemy import select

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from dotenv import load_dotenv
from pronto_shared.constants import OrderStatus, SessionStatus
from pronto_shared.db import get_session
from pronto_shared.models import DiningSession, MenuItem, Order, OrderItem
from pronto_shared.services.order_state_machine import (
    OrderEvent,
    OrderStateError,
    TransitionContext,
    order_state_machine,
)

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)


ACTIVE_SESSION_STATUSES = {
    SessionStatus.OPEN.value,
    SessionStatus.ACTIVE.value,
    SessionStatus.AWAITING_TIP.value,
    SessionStatus.AWAITING_PAYMENT.value,
}


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


def _resolve_session_id(
    db_session,
    *,
    explicit_session_id: str | None,
    table_id: str | None,
) -> uuid.UUID | None:
    if explicit_session_id:
        return _parse_uuid(explicit_session_id, "session_id", required=True)

    if not table_id:
        return None

    table_uuid = _parse_uuid(table_id, "table_id", required=True)
    session_row = (
        db_session.execute(
            select(DiningSession)
            .where(
                DiningSession.table_id == table_uuid,
                DiningSession.status.in_(ACTIVE_SESSION_STATUSES),
            )
            .order_by(DiningSession.opened_at.desc())
        )
        .scalars()
        .first()
    )
    if session_row is None:
        raise ValueError(
            f"No existe dining session activa para la mesa {table_uuid}. Usa --session-id."
        )
    return session_row.id


def _print_error(as_json: bool, message: str) -> None:
    if as_json:
        print(json.dumps({"status": "error", "message": message}))
    else:
        print(f"Error: {message}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Crear orden en PRONTO")
    parser.add_argument("--customer-id", required=True, help="UUID del cliente")
    parser.add_argument("--session-id", help="UUID de la dining session")
    parser.add_argument("--table-id", help="UUID de la mesa (resuelve sesión activa)")
    parser.add_argument(
        "--employee-id",
        help="UUID del mesero (si se define, intenta aceptar la orden a queued)",
    )
    parser.add_argument("--items", help="JSON array de items [{menu_item_id, quantity, notes}]")
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    try:
        items_data = json.loads(args.items) if args.items else []
    except json.JSONDecodeError as exc:
        _print_error(args.json, f"JSON inválido en --items: {exc}")
        sys.exit(1)

    if not isinstance(items_data, list) or len(items_data) == 0:
        _print_error(args.json, "Debe enviar al menos 1 item en --items")
        sys.exit(1)

    try:
        customer_id = _parse_uuid(args.customer_id, "customer_id", required=True)
    except ValueError as exc:
        _print_error(args.json, str(exc))
        sys.exit(1)

    with get_session() as db_session:
        try:
            session_id = _resolve_session_id(
                db_session,
                explicit_session_id=args.session_id,
                table_id=args.table_id,
            )
            waiter_id = _parse_uuid(args.employee_id, "employee_id", required=False)

            order = Order(
                customer_id=customer_id,
                session_id=session_id,
            )
            db_session.add(order)
            db_session.flush()

            order.mark_status(OrderStatus.NEW.value)

            subtotal = Decimal("0.00")
            all_quick_serve = True

            for item_data in items_data:
                menu_item_id = _parse_uuid(item_data.get("menu_item_id"), "menu_item_id")
                quantity = int(item_data.get("quantity", 1))
                notes = str(item_data.get("notes") or "").strip() or None

                if quantity <= 0:
                    raise ValueError("quantity debe ser mayor a 0")

                menu_item = db_session.get(MenuItem, menu_item_id)
                if menu_item is None:
                    raise ValueError(f"Menu item no encontrado: {menu_item_id}")

                unit_price = Decimal(str(menu_item.price or 0))
                subtotal += unit_price * quantity
                if not bool(getattr(menu_item, "is_quick_serve", False)):
                    all_quick_serve = False

                db_session.add(
                    OrderItem(
                        order_id=order.id,
                        menu_item_id=menu_item.id,
                        quantity=quantity,
                        unit_price=float(unit_price),
                        notes=notes,
                    )
                )

            order.subtotal = float(subtotal)
            order.tax_amount = 0.0
            order.tip_amount = 0.0
            order.total_amount = float(subtotal)

            if waiter_id:
                queue_context = TransitionContext(
                    order=order,
                    event=OrderEvent.ACCEPT_OR_QUEUE,
                    actor_scope="system",
                    actor_id=waiter_id,
                )
                order_state_machine.apply_transition(queue_context)

                if all_quick_serve and order.workflow_status == OrderStatus.QUEUED.value:
                    quick_context = TransitionContext(
                        order=order,
                        event=OrderEvent.SKIP_KITCHEN,
                        actor_scope="system",
                    )
                    order_state_machine.apply_transition(quick_context)

            db_session.commit()
            db_session.refresh(order)

            payload = {
                "id": str(order.id),
                "customer_id": str(order.customer_id) if order.customer_id else None,
                "session_id": str(order.session_id) if order.session_id else None,
                "status": order.workflow_status,
                "total": float(order.total_amount or 0),
            }
            if args.json:
                print(json.dumps({"status": "success", "order": payload}))
            else:
                print(
                    f"Orden creada: ID={payload['id']}, Status={payload['status']}, Total=${payload['total']:.2f}"
                )
        except (ValueError, OrderStateError) as exc:
            db_session.rollback()
            _print_error(args.json, str(exc))
            sys.exit(1)
        except Exception as exc:
            db_session.rollback()
            _print_error(args.json, f"Error inesperado creando orden: {exc}")
            sys.exit(1)


if __name__ == "__main__":
    main()
