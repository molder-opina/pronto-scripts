#!/usr/bin/env python3
"""Crear producto en el menú PRONTO.

Uso:
    python crear_producto.py --name "Hamburguesa Clásica" --price 12.50 --category-id 1
    python crear_producto.py --name "Papas Fritas" --price 5.00 --category-id 2 --available

Args:
    --name: Nombre del producto (requerido)
    --price: Precio decimal (requerido)
    --category-id: ID de la categoría (requerido)
    --description: Descripción opcional
    --available: Si está disponible (default: False)
    --prep-time: Tiempo de preparación en minutos (default: 15)
    --json: Salida en JSON
"""

import argparse
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
    parser = argparse.ArgumentParser(description="Crear producto en el menú PRONTO")
    parser.add_argument("--name", required=True, help="Nombre del producto")
    parser.add_argument(
        "--price", required=True, type=float, help="Precio del producto"
    )
    parser.add_argument(
        "--category-id", required=True, type=int, help="ID de la categoría"
    )
    parser.add_argument("--description", default="", help="Descripción del producto")
    parser.add_argument("--available", action="store_true", help="Producto disponible")
    parser.add_argument(
        "--prep-time", type=int, default=15, help="Tiempo de preparación (minutos)"
    )
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    with get_session() as session:
        item = MenuItem(
            name=args.name,
            price=Decimal(str(args.price)),
            category_id=args.category_id,
            description=args.description,
            is_available=args.available,
            preparation_time_minutes=args.prep_time,
        )
        session.add(item)
        session.commit()
        session.refresh(item)

        if args.json:
            import json

            print(
                json.dumps(
                    {
                        "status": "success",
                        "product": {
                            "id": item.id,
                            "name": item.name,
                            "price": float(item.price),
                            "category_id": item.category_id,
                            "is_available": item.is_available,
                        },
                    }
                )
            )
        else:
            print(
                f"Producto creado exitosamente: ID={item.id}, Name={item.name}, Price=${item.price}"
            )


if __name__ == "__main__":
    main()
