#!/usr/bin/env python3
"""Modificar cliente en PRONTO.

Uso:
    python modificar_cliente.py --id 123 --name "Nuevo Nombre"
    python modificar_cliente.py --id 123 --email "nuevo@email.com" --phone "0987654321"

Args:
    --id: ID del cliente (requerido)
    --name: Nuevo nombre
    --email: Nuevo email
    --phone: Nuevo teléfono
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

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)


def main():
    parser = argparse.ArgumentParser(description="Modificar cliente en PRONTO")
    parser.add_argument("--id", required=True, type=int, help="ID del cliente")
    parser.add_argument("--name", help="Nuevo nombre")
    parser.add_argument("--email", help="Nuevo email")
    parser.add_argument("--phone", help="Nuevo teléfono")
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    updates = {}
    if args.name is not None:
        updates["name"] = args.name
    if args.email is not None:
        updates["email"] = args.email
    if args.phone is not None:
        updates["phone"] = args.phone

    if not updates:
        if args.json:
            print('{"status": "error", "message": "No se especificó ningún campo"}')
        else:
            print("Error: No se especificó ningún campo a modificar")
        sys.exit(1)

    with get_session() as session:
        customer = session.query(Customer).filter(Customer.id == args.id).first()
        if not customer:
            if args.json:
                print('{"status": "error", "message": "Cliente no encontrado"}')
            else:
                print(f"Error: Cliente con ID {args.id} no encontrado")
            sys.exit(1)

        for key, value in updates.items():
            setattr(customer, key, value)

        session.commit()
        session.refresh(customer)

        if args.json:
            print(
                json.dumps(
                    {
                        "status": "success",
                        "customer": {
                            "id": customer.id,
                            "name": customer.name,
                            "email": customer.email,
                            "phone": customer.phone,
                        },
                    }
                )
            )
        else:
            print(f"Cliente modificado: ID={customer.id}, Name={customer.name}")


if __name__ == "__main__":
    main()
