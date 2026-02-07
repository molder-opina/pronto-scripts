#!/usr/bin/env python3
"""Listar productos del menú PRONTO.

Uso:
    python listar_productos.py
    python listar_productos.py --category-id 1
    python listar_productos.py --available-only
    python listar_productos.py --json

Args:
    --category-id: Filtrar por categoría
    --available-only: Solo productos disponibles
    --json: Salida en JSON
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from dotenv import load_dotenv
from pronto_shared.db import get_session
from pronto_shared.models import MenuItem

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)


def main():
    parser = argparse.ArgumentParser(description="Listar productos del menú PRONTO")
    parser.add_argument("--category-id", type=int, help="Filtrar por categoría")
    parser.add_argument(
        "--available-only", action="store_true", help="Solo disponibles"
    )
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    with get_session() as session:
        query = session.query(MenuItem)

        if args.category_id:
            query = query.filter(MenuItem.category_id == args.category_id)
        if args.available_only:
            query = query.filter(MenuItem.is_available == True)

        items = query.order_by(MenuItem.name).all()

        if args.json:
            print(
                json.dumps(
                    {
                        "status": "success",
                        "count": len(items),
                        "products": [
                            {
                                "id": item.id,
                                "name": item.name,
                                "price": float(item.price),
                                "category_id": item.category_id,
                                "is_available": item.is_available,
                                "prep_time": item.preparation_time_minutes,
                            }
                            for item in items
                        ],
                    }
                )
            )
        else:
            print(f"{'ID':<5} {'NOMBRE':<40} {'PRECIO':<10} {'DISP':<5} {'CAT'}")
            print("-" * 70)
            for item in items:
                disp = "Sí" if item.is_available else "No"
                print(
                    f"{item.id:<5} {item.name[:40]:<40} ${item.price:<9.2f} {disp:<5} {item.category_id}"
                )


if __name__ == "__main__":
    main()
