#!/usr/bin/env python3
"""Gestionar aditamentos (Modifiers) en PRONTO.

Uso:
    python crear_modifier.py --name "Extra Queso" --price 2.50 --group-id 1
    python eliminar_modifier.py --id 5
    python modificar_modifier.py --id 5 --price 3.00

Args:
    --id: ID del modifier
    --name: Nombre del modifier
    --price: Precio adicional
    --group-id: ID del grupo de modifiers
    --available: Si está disponible
    --json: Salida en JSON
"""

import argparse
import json
import sys
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from dotenv import load_dotenv
from pronto_shared.db import get_session
from pronto_shared.models import Modifier, ModifierGroup

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)


def crear_modifier(args):
    parser = argparse.ArgumentParser(description="Crear modifier")
    parser.add_argument("--name", required=True)
    parser.add_argument("--price", required=True, type=float)
    parser.add_argument("--group-id", required=True, type=int)
    parser.add_argument("--available", type=lambda x: x.lower() == "true", default=True)
    opts = parser.parse_args()

    with get_session() as session:
        group = (
            session.query(ModifierGroup)
            .filter(ModifierGroup.id == opts.group_id)
            .first()
        )
        if not group:
            if opts.json:
                print(
                    json.dumps(
                        {
                            "status": "error",
                            "message": f"Grupo {opts.group_id} no encontrado",
                        }
                    )
                )
            else:
                print(f"Error: Grupo {opts.group_id} no encontrado")
            sys.exit(1)

        modifier = Modifier(
            name=opts.name,
            price_adjustment=Decimal(str(opts.price)),
            modifier_group_id=opts.group_id,
            is_available=True,
        )
        session.add(modifier)
        session.commit()
        session.refresh(modifier)

        if opts.json:
            print(
                json.dumps(
                    {
                        "status": "success",
                        "modifier": {
                            "id": modifier.id,
                            "name": modifier.name,
                            "price_adjustment": float(modifier.price_adjustment),
                        },
                    }
                )
            )
        else:
            print(
                f"Modifier creado: ID={modifier.id}, Name={modifier.name}, Price=${modifier.price_adjustment}"
            )


def eliminar_modifier(args):
    parser = argparse.ArgumentParser(description="Eliminar modifier")
    parser.add_argument("--id", required=True, type=int)
    opts = parser.parse_args()

    with get_session() as session:
        modifier = session.query(Modifier).filter(Modifier.id == opts.id).first()
        if not modifier:
            if opts.json:
                print(
                    json.dumps({"status": "error", "message": "Modifier no encontrado"})
                )
            else:
                print(f"Error: Modifier {opts.id} no encontrado")
            sys.exit(1)

        session.delete(modifier)
        session.commit()

        if opts.json:
            print(json.dumps({"status": "success", "deleted_id": opts.id}))
        else:
            print(f"Modifier eliminado: ID={opts.id}")


def modificar_modifier(args):
    parser = argparse.ArgumentParser(description="Modificar modifier")
    parser.add_argument("--id", required=True, type=int)
    parser.add_argument("--name")
    parser.add_argument("--price", type=float)
    parser.add_argument("--available", type=lambda x: x.lower() == "true")
    opts = parser.parse_args()

    updates = {}
    if opts.name is not None:
        updates["name"] = opts.name
    if opts.price is not None:
        updates["price_adjustment"] = Decimal(str(opts.price))
    if opts.available is not None:
        updates["is_available"] = opts.available

    with get_session() as session:
        modifier = session.query(Modifier).filter(Modifier.id == opts.id).first()
        if not modifier:
            if opts.json:
                print(
                    json.dumps({"status": "error", "message": "Modifier no encontrado"})
                )
            else:
                print(f"Error: Modifier {opts.id} no encontrado")
            sys.exit(1)

        for key, value in updates.items():
            setattr(modifier, key, value)

        session.commit()
        session.refresh(modifier)

        if opts.json:
            print(
                json.dumps(
                    {
                        "status": "success",
                        "modifier": {
                            "id": modifier.id,
                            "name": modifier.name,
                            "price_adjustment": float(modifier.price_adjustment),
                        },
                    }
                )
            )
        else:
            print(f"Modifier modificado: ID={modifier.id}, Name={modifier.name}")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Gestionar modifiers PRONTO")
    subparsers = parser.add_subparsers(dest="command", help="Comandos")

    create_parser = subparsers.add_parser("crear", help="Crear modifier")
    create_parser.add_argument("--name", required=True)
    create_parser.add_argument("--price", required=True, type=float)
    create_parser.add_argument("--group-id", required=True, type=int)

    delete_parser = subparsers.add_parser("eliminar", help="Eliminar modifier")
    delete_parser.add_argument("--id", required=True, type=int)

    update_parser = subparsers.add_parser("modificar", help="Modificar modifier")
    update_parser.add_argument("--id", required=True, type=int)
    update_parser.add_argument("--name")
    update_parser.add_argument("--price", type=float)

    parser.add_argument("--json", action="store_true")

    args = parser.parse_args()

    if args.command == "crear":
        crear_modifier(args)
    elif args.command == "eliminar":
        eliminar_modifier(args)
    elif args.command == "modificar":
        modificar_modifier(args)
    else:
        parser.print_help()
