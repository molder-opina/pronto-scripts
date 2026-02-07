#!/usr/bin/env python3
"""Crear cliente en PRONTO.

Uso:
    python crear_cliente.py --name "Juan Pérez" --email "juan@email.com" --phone "1234567890"
    python crear_cliente.py --name "María García" --email "maria@email.com"

Args:
    --name: Nombre del cliente (requerido)
    --email: Email del cliente
    --phone: Teléfono del cliente
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
    parser = argparse.ArgumentParser(description="Crear cliente en PRONTO")
    parser.add_argument("--name", required=True, help="Nombre del cliente")
    parser.add_argument("--email", help="Email del cliente")
    parser.add_argument("--phone", help="Teléfono del cliente")
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    with get_session() as session:
        customer = Customer(
            name=args.name,
            email=args.email,
            phone=args.phone,
        )
        session.add(customer)
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
            print(
                f"Cliente creado: ID={customer.id}, Name={customer.name}, Email={customer.email}"
            )


if __name__ == "__main__":
    main()
