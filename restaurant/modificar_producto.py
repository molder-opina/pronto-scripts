#!/usr/bin/env python3
"""Modificar producto del menú PRONTO.

Uso:
    python modificar_producto.py --id 123 --name "Nuevo Nombre"
    python modificar_producto.py --id 123 --price 15.00 --available false
    python modificar_producto.py --id 123 --prep-time 20

Args:
    --id: ID del producto a modificar (requerido)
    --name: Nuevo nombre
    --price: Nuevo precio
    --description: Nueva descripción
    --available: Disponibilidad (true/false)
    --prep-time: Tiempo de preparación
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
from pronto_shared.models import MenuItem

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)


def main():
    parser = argparse.ArgumentParser(description="Modificar producto del menú PRONTO")
    parser.add_argument("--id", required=True, type=int, help="ID del producto")
    parser.add_argument("--name", help="Nuevo nombre")
    parser.add_argument("--price", type=float, help="Nuevo precio")
    parser.add_argument("--description", help="Nueva descripción")
    parser.add_argument(
        "--available", type=lambda x: x.lower() == "true", help="Disponibilidad"
    )
    parser.add_argument("--prep-time", type=int, help="Tiempo de preparación (minutos)")
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    updates = {}
    if args.name is not None:
        updates["name"] = args.name
    if args.price is not None:
        updates["price"] = Decimal(str(args.price))
    if args.description is not None:
        updates["description"] = args.description
    if args.available is not None:
        updates["is_available"] = args.available
    if args.prep_time is not None:
        updates["preparation_time_minutes"] = args.prep_time

    if not updates:
        if args.json:
            print(
                '{"status": "error", "message": "No se especificó ningún campo a modificar"}'
            )
        else:
            print("Error: No se especificó ningún campo a modificar")
        sys.exit(1)

    with get_session() as session:
        item = session.query(MenuItem).filter(MenuItem.id == args.id).first()
        if not item:
            if args.json:
                print('{"status": "error", "message": "Producto no encontrado"}')
            else:
                print(f"Error: Producto con ID {args.id} no encontrado")
            sys.exit(1)

        for key, value in updates.items():
            setattr(item, key, value)

        session.commit()
        session.refresh(item)

        if args.json:
            print(
                json.dumps(
                    {
                        "status": "success",
                        "product": {
                            "id": item.id,
                            "name": item.name,
                            "price": float(item.price),
                            "is_available": item.is_available,
                        },
                    }
                )
            )
        else:
            print(
                f"Producto modificado: ID={item.id}, Name={item.name}, Price=${item.price}"
            )


if __name__ == "__main__":
    main()
