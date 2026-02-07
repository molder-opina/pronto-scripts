#!/usr/bin/env python3
"""Buscar cliente en PRONTO por nombre, email o teléfono.

Uso:
    python buscar_cliente.py --query "Juan"
    python buscar_cliente.py --email "juan@email.com"
    python buscar_cliente.py --phone "1234567890"

Args:
    --query: Buscar por nombre (contiene)
    --email: Buscar por email exacto
    --phone: Buscar por teléfono exacto
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
    parser = argparse.ArgumentParser(description="Buscar cliente en PRONTO")
    parser.add_argument("--query", help="Buscar por nombre (contiene)")
    parser.add_argument("--email", help="Buscar por email exacto")
    parser.add_argument("--phone", help="Buscar por teléfono exacto")
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    if not any([args.query, args.email, args.phone]):
        if args.json:
            print(
                '{"status": "error", "message": "Debe especificar --query, --email o --phone"}'
            )
        else:
            print("Error: Debe especificar --query, --email o --phone")
        sys.exit(1)

    with get_session() as session:
        query = session.query(Customer)

        if args.email:
            query = query.filter(Customer.email.ilike(f"%{args.email}%"))
        elif args.phone:
            query = query.filter(Customer.phone.ilike(f"%{args.phone}%"))
        elif args.query:
            query = query.filter(Customer.name.ilike(f"%{args.query}%"))

        customers = query.limit(50).all()

        if args.json:
            print(
                json.dumps(
                    {
                        "status": "success",
                        "count": len(customers),
                        "customers": [
                            {
                                "id": c.id,
                                "name": c.name,
                                "email": c.email,
                                "phone": c.phone,
                            }
                            for c in customers
                        ],
                    }
                )
            )
        else:
            print(f"{'ID':<5} {'NOMBRE':<40} {'EMAIL':<30} {'TELÉFONO'}")
            print("-" * 100)
            for c in customers:
                print(
                    f"{c.id:<5} {c.name[:40]:<40} {c.email or '-':<30} {c.phone or '-'}"
                )


if __name__ == "__main__":
    main()
