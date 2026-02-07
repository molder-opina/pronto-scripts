#!/usr/bin/env python3
"""Eliminar producto del menú PRONTO.

Uso:
    python eliminar_producto.py --id 123
    python eliminar_producto.py --id 123 --force  # Forzar eliminación aunque tenga órdenes

Args:
    --id: ID del producto a eliminar (requerido)
    --force: Forzar eliminación sin validar dependencias
    --json: Salida en JSON
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from dotenv import load_dotenv
from pronto_shared.db import get_session
from pronto_shared.models import MenuItem
from sqlalchemy import text

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)


def main():
    parser = argparse.ArgumentParser(description="Eliminar producto del menú PRONTO")
    parser.add_argument("--id", required=True, type=int, help="ID del producto")
    parser.add_argument("--force", action="store_true", help="Forzar eliminación")
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    with get_session() as session:
        item = session.query(MenuItem).filter(MenuItem.id == args.id).first()
        if not item:
            if args.json:
                print('{"status": "error", "message": "Producto no encontrado"}')
            else:
                print(f"Error: Producto con ID {args.id} no encontrado")
            sys.exit(1)

        if not args.force:
            result = session.execute(
                text("SELECT COUNT(*) FROM order_items WHERE menu_item_id = :item_id"),
                {"item_id": args.id},
            )
            count = result.scalar()
            if count > 0:
                if args.json:
                    print(
                        json.dumps(
                            {
                                "status": "error",
                                "message": f"Producto tiene {count} órdenes asociadas",
                            }
                        )
                    )
                else:
                    print(
                        f"Error: Producto tiene {count} órdenes asociadas. Usar --force para eliminar."
                    )
                sys.exit(1)

        session.delete(item)
        session.commit()

        if args.json:
            print(json.dumps({"status": "success", "deleted_id": args.id}))
        else:
            print(f"Producto eliminado: ID={args.id}, Name={item.name}")


if __name__ == "__main__":
    import json

    main()
