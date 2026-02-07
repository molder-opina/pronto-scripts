#!/usr/bin/env python3
"""Gestionar mesas en PRONTO.

Uso:
    python crear_mesa.py --number 5 --capacity 4
    python eliminar_mesa.py --id 3
    python asignar_mesa.py --mesa-id 5 --orden-id 123
    python listar_mesas.py

Args:
    --number: Número de mesa
    --capacity: Capacidad de personas
    --id: ID de la mesa
    --mesa-id: ID de la mesa
    --orden-id: ID de la orden
    --active: Mesa activa (default: true)
    --json: Salida en JSON
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from dotenv import load_dotenv
from pronto_shared.db import get_session
from pronto_shared.models import Table

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)


def crear_mesa(args):
    parser = argparse.ArgumentParser(description="Crear mesa")
    parser.add_argument("--number", required=True, type=int)
    parser.add_argument("--capacity", required=True, type=int)
    parser.add_argument("--active", type=lambda x: x.lower() == "true", default=True)
    opts = parser.parse_args([__file__, "--number", str(opts.number)])

    with get_session() as session:
        existing = session.query(Table).filter(Table.number == opts.number).first()
        if existing:
            if opts.json:
                print(
                    json.dumps(
                        {"status": "error", "message": f"Mesa {opts.number} ya existe"}
                    )
                )
            else:
                print(f"Error: Mesa {opts.number} ya existe")
            sys.exit(1)

        table = Table(number=opts.number, capacity=opts.capacity, is_active=True)
        session.add(table)
        session.commit()
        session.refresh(table)

        if opts.json:
            print(
                json.dumps(
                    {
                        "status": "success",
                        "mesa": {
                            "id": table.id,
                            "number": table.number,
                            "capacity": table.capacity,
                        },
                    }
                )
            )
        else:
            print(
                f"Mesa creada: ID={table.id}, Number={table.number}, Capacity={table.capacity}"
            )


def eliminar_mesa(args):
    parser = argparse.ArgumentParser(description="Eliminar mesa")
    parser.add_argument("--id", required=True, type=int)
    opts = parser.parse_args()

    with get_session() as session:
        table = session.query(Table).filter(Table.id == opts.id).first()
        if not table:
            if opts.json:
                print(json.dumps({"status": "error", "message": "Mesa no encontrada"}))
            else:
                print(f"Error: Mesa {opts.id} no encontrada")
            sys.exit(1)

        session.delete(table)
        session.commit()

        if opts.json:
            print(json.dumps({"status": "success", "deleted_id": opts.id}))
        else:
            print(f"Mesa eliminada: ID={opts.id}")


def asignar_mesa(opts):
    with get_session() as session:
        from pronto_shared.models import Order

        order = session.query(Order).filter(Order.id == opts.orden_id).first()
        if not order:
            if opts.json:
                print(json.dumps({"status": "error", "message": "Orden no encontrada"}))
            else:
                print(f"Error: Orden {opts.orden_id} no encontrada")
            sys.exit(1)

        order.table_id = opts.mesa_id
        session.commit()

        if opts.json:
            print(
                json.dumps(
                    {
                        "status": "success",
                        "orden_id": opts.orden_id,
                        "mesa_id": opts.mesa_id,
                    }
                )
            )
        else:
            print(f"Orden {opts.orden_id} asignada a mesa {opts.mesa_id}")


def listar_mesas(args):
    with get_session() as session:
        tables = session.query(Table).order_by(Table.number).all()

        if args.json:
            print(
                json.dumps(
                    {
                        "status": "success",
                        "count": len(tables),
                        "mesas": [
                            {
                                "id": t.id,
                                "number": t.number,
                                "capacity": t.capacity,
                                "active": t.is_active,
                            }
                            for t in tables
                        ],
                    }
                )
            )
        else:
            print(f"{'ID':<5} {'NÚMERO':<10} {'CAPACIDAD':<10} {'ACTIVA'}")
            print("-" * 40)
            for t in tables:
                print(
                    f"{t.id:<5} {t.number:<10} {t.capacity:<10} {'Sí' if t.is_active else 'No'}"
                )


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Gestionar mesas PRONTO")
    subparsers = parser.add_subparsers(dest="command", help="Comandos")

    create_parser = subparsers.add_parser("crear", help="Crear mesa")
    create_parser.add_argument("--number", required=True, type=int)
    create_parser.add_argument("--capacity", required=True, type=int)

    delete_parser = subparsers.add_parser("eliminar", help="Eliminar mesa")
    delete_parser.add_argument("--id", required=True, type=int)

    assign_parser = subparsers.add_parser("asignar", help="Asignar mesa a orden")
    assign_parser.add_argument("--mesa-id", required=True, type=int)
    assign_parser.add_argument("--orden-id", required=True, type=int)

    list_parser = subparsers.add_parser("listar", help="Listar mesas")

    parser.add_argument("--json", action="store_true")

    args = parser.parse_args()

    if args.command == "crear":
        crear_mesa(args)
    elif args.command == "eliminar":
        eliminar_mesa(args)
    elif args.command == "asignar":
        asignar_mesa(args)
    elif args.command == "listar":
        listar_mesas(args)
    else:
        parser.print_help()
