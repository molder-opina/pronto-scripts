#!/usr/bin/env python3
"""Login de empleado y generar JWT token.

Uso:
    python login_empleado.py --email "admin@pronto.com" --scope admin
    python login_empleado.py --email "cocina@pronto.com" --scope chef --json

Args:
    --email: Email del empleado
    --scope: Scope del empleado (admin, waiter, chef, cashier, system)
    --json: Salida en JSON
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from dotenv import load_dotenv
from pronto_shared.db import get_session
from pronto_shared.models import Employee
from pronto_shared.jwt_service import create_access_token

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)


def main():
    parser = argparse.ArgumentParser(description="Login de empleado")
    parser.add_argument("--email", required=True, help="Email del empleado")
    parser.add_argument(
        "--scope",
        required=True,
        choices=["admin", "waiter", "chef", "cashier", "system"],
        help="Scope",
    )
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    with get_session() as session:
        employee = session.query(Employee).filter(Employee.email == args.email).first()
        if not employee:
            if args.json:
                print(
                    json.dumps({"status": "error", "message": "Empleado no encontrado"})
                )
            else:
                print(f"Error: Empleado con email {args.email} no encontrado")
            sys.exit(1)

        scopes = employee.get_scopes()
        if args.scope not in scopes:
            if args.json:
                print(
                    json.dumps(
                        {
                            "status": "error",
                            "message": f"Scope '{args.scope}' no permitido. Scopes disponibles: {scopes}",
                        }
                    )
                )
            else:
                print(
                    f"Error: Scope '{args.scope}' no permitido. Scopes disponibles: {scopes}"
                )
            sys.exit(1)

        token = create_access_token(
            employee_id=employee.id,
            employee_name=employee.name,
            employee_email=employee.email,
            employee_role=employee.role,
            employee_additional_roles=scopes,
            active_scope=args.scope,
        )

        if args.json:
            print(
                json.dumps(
                    {
                        "status": "success",
                        "employee": {
                            "id": employee.id,
                            "name": employee.name,
                            "email": employee.email,
                            "role": employee.role,
                            "scopes": scopes,
                        },
                        "token": token,
                    }
                )
            )
        else:
            print(f"LOGIN EXITOSO")
            print(f"  Empleado: {employee.name}")
            print(f"  Role: {employee.role}")
            print(f"  Scopes: {scopes}")
            print(f"  Token: {token[:50]}...")


if __name__ == "__main__":
    main()
