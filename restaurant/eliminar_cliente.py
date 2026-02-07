#!/usr/bin/env python3
"""Eliminar cliente en PRONTO.

Uso:
    python eliminar_cliente.py --id 123

Args:
    --id: ID del cliente a eliminar (requerido)
    --force: Forzar eliminación aunque tenga órdenes
    --json: Salida en JSON
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from dotenv import load_dotenv
from pronto_shared.db import get_session
from pronto_shared.models import Customer
from sqlalchemy import text

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)


def main():
    parser = argparse.ArgumentParser(description="Eliminar cliente en PRONTO")
    parser.add_argument("--id", required=True, type=int, help="ID del cliente")
    parser.add_argument("--force", action="store_true", help="Forzar eliminación")
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    with get_session() as session:
        customer = session.query(Customer).filter(Customer.id == args.id).first()
        if not customer:
            if args.json:
                print('{"status": "error", "message": "Cliente no encontrado"}')
            else:
                print(f"Error: Cliente con ID {args.id} no encontrado")
            sys.exit(1)

        if not args.force:
            result = session.execute(
                text("SELECT COUNT(*) FROM orders WHERE customer_id = :customer_id"),
                {"customer_id": args.id},
            )
            count = result.scalar() or 0
            if count > 0:
                if args.json:
                    print(
                        json.dumps(
                            {
                                "status": "error",
                                "message": f"Cliente tiene {count} órdenes asociadas",
                            }
                        )
                    )
                else:
                    print(f"Error: Cliente tiene {count} órdenes. Usar --force.")
                sys.exit(1)

        session.delete(customer)
        session.commit()

        if args.json:
            print(json.dumps({"status": "success", "deleted_id": args.id}))
        else:
            print(f"Cliente eliminado: ID={args.id}, Name={customer.name}")


if __name__ == "__main__":
    main()
