#!/usr/bin/env python3
"""
Script de prueba para verificar credenciales
"""

import os
import sys

# Add pronto-shared to path
sys.path.insert(0, "/Users/molder/projects/github-molder/pronto/pronto-libs/src")

from pronto_shared.security import hash_credentials, verify_credentials, hash_identifier
from pronto_shared.db import get_session, init_engine
from pronto_shared.models import Employee


def test_credentials():
    """Prueba credenciales de test."""

    # Inicializar engine
    db_url = os.environ.get("DATABASE_URL")
    if not db_url:
        print("ERROR: DATABASE_URL no está definido")
        sys.exit(1)

    init_engine(db_url)

    test_email = "juan@pronto.com"
    test_password = "ChangeMe!123"

    print(f"Probando credenciales: {test_email} / {test_password}")
    print("")

    # Generar hash
    expected_hash = hash_credentials(test_email, test_password)
    print(f"Hash esperado: {expected_hash}")
    print("")

    # Buscar empleado
    with get_session() as session:
        email_hash = hash_identifier(test_email)
        employee = (
            session.query(Employee).filter(Employee.email_hash == email_hash).first()
        )

        if employee:
            print(f"Empleado encontrado:")
            print(f"  - ID: {employee.id}")
            print(f"  - Email (hash): {employee.email_hash}")
            print(f"  - Auth hash: {employee.auth_hash}")
            print("")

            # Verificar credenciales
            if verify_credentials(test_email, test_password, employee.auth_hash):
                print("✓ Credenciales válidas")
            else:
                print("✗ Credenciales inválidas")
                print("")
                print("Verificando manualmente...")
                print(f"  Hash generado: {expected_hash}")
                print(f"  Hash en BD:    {employee.auth_hash}")
                print(f"  Coinciden: {expected_hash == employee.auth_hash}")
        else:
            print(f"✗ Empleado no encontrado para {test_email}")


if __name__ == "__main__":
    test_credentials()
