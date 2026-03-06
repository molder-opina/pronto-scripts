#!/usr/bin/env python3
"""
Script para actualizar contraseñas de empleados con credenciales de test
"""

import os
import sys

# Add pronto-shared to path
sys.path.insert(0, "/Users/molder/projects/github-molder/pronto/pronto-libs/src")

from pronto_shared.security import hash_credentials, hash_identifier
from pronto_shared.db import get_session, init_engine
from pronto_shared.models import Employee


def update_employee_passwords():
    """Actualiza contraseñas de empleados para testing."""

    # Inicializar engine
    db_url = os.environ.get("DATABASE_URL")
    if not db_url:
        print("ERROR: DATABASE_URL no está definido")
        sys.exit(1)

    init_engine(db_url)

    # Credenciales de test
    test_employees = [
        ("juan@pronto.com", "admin", "ChangeMe!123"),
        ("maria@pronto.com", "waiter", "ChangeMe!123"),
        ("carlos@pronto.com", "chef", "ChangeMe!123"),
        ("ana@pronto.com", "waiter", "ChangeMe!123"),
        ("pedro@pronto.com", "cashier", "ChangeMe!123"),
    ]

    print("Actualizando contraseñas de empleados...")

    with get_session() as session:
        for email, role, password in test_employees:
            # Buscar empleado por email_hash
            email_hash = hash_identifier(email)
            employee = (
                session.query(Employee)
                .filter(Employee.email_hash == email_hash)
                .first()
            )

            if employee:
                # Generar hash nuevo
                new_hash = hash_credentials(email, password)

                # Actualizar
                employee.auth_hash = new_hash

                print(f"✓ {email} ({role}) - contraseña actualizada")
            else:
                print(
                    f"✗ {email} ({role}) - empleado no encontrado (hash: {email_hash})"
                )

        session.commit()

    print("\nContraseñas actualizadas exitosamente!")
    print("\nCredenciales de prueba:")
    print("  Email: juan@pronto.com (admin) | Password: ChangeMe!123")
    print("  Email: maria@pronto.com (waiter) | Password: ChangeMe!123")
    print("  Email: carlos@pronto.com (chef) | Password: ChangeMe!123")
    print("  Email: ana@pronto.com (waiter) | Password: ChangeMe!123")
    print("  Email: pedro@pronto.com (cashier) | Password: ChangeMe!123")


if __name__ == "__main__":
    update_employee_passwords()
