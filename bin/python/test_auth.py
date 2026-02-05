#!/usr/bin/env python3
"""
Script de prueba para diagnóstico del sistema de autenticación.
Verifica la creación de empleados, hash de contraseñas y proceso de login.
"""

from __future__ import annotations

import os
import sys
import traceback
from pathlib import Path


def _load_dependencies():
    """Load app dependencies after adjusting sys.path."""
    repo_root = Path(__file__).resolve().parents[3]
    sys.path.insert(0, str(repo_root / "pronto-libs/src"))
    try:
        import pronto_shared  # noqa: F401
    except ImportError:
        raise ImportError(
            "pronto_shared package not found. Install it from pronto-libs repo:\n"
            "cd ../pronto-libs && pip install -e ."
        )

    from pronto_shared.db import get_session
    from pronto_shared.models import Employee
    from pronto_shared.security import (
        decrypt_string,
        encrypt_string,
        hash_credentials,
        hash_identifier,
        verify_credentials,
    )

    return (
        get_session,
        Employee,
        decrypt_string,
        encrypt_string,
        hash_credentials,
        hash_identifier,
        verify_credentials,
    )


(
    get_session,
    Employee,
    decrypt_string,
    encrypt_string,
    hash_credentials,
    hash_identifier,
    verify_credentials,
) = _load_dependencies()


def print_separator(title=""):
    print("\n" + "=" * 80)
    if title:
        print(f"  {title}")
        print("=" * 80)


def test_encryption():
    """Test encryption/decryption."""
    print_separator("PRUEBA 1: Encriptación/Desencriptación")

    test_email = "admin@cafeteria.test"
    encrypted = encrypt_string(test_email)
    decrypted = decrypt_string(encrypted)

    print(f"Email original:    {test_email}")
    print(
        f"Email encriptado:  {encrypted[:50]}..."
        if len(encrypted) > 50
        else f"Email encriptado:  {encrypted}"
    )
    print(f"Email desencriptado: {decrypted}")
    print(f"✓ Match: {test_email == decrypted}")


def test_hashing():
    """Test hashing functions."""
    print_separator("PRUEBA 2: Funciones de Hash")

    test_email = "admin@cafeteria.test"
    test_password = "ChangeMe!123"  # nosec B105

    email_hash = hash_identifier(test_email)
    cred_hash = hash_credentials(test_email, test_password)

    print(f"Email:       {test_email}")
    print(f"Password:    {test_password}")
    print(f"Email hash:  {email_hash}")
    print(f"Cred hash:   {cred_hash}")

    # Verificar credenciales
    is_valid = verify_credentials(test_email, test_password, cred_hash)
    print(f"✓ Verificación: {is_valid}")

    # Probar con password incorrecto
    is_invalid = verify_credentials(test_email, "WrongPassword", cred_hash)
    print(f"✓ Password incorrecto rechazado: {not is_invalid}")


def test_employee_creation():
    """Test employee creation and password setting."""
    print_separator("PRUEBA 3: Creación de Empleado")

    with get_session() as session:
        # Buscar el admin
        test_email = "admin@cafeteria.test"
        email_hash = hash_identifier(test_email)

        employee = session.query(Employee).filter(Employee.email_hash == email_hash).first()

        if not employee:
            print(f"❌ No se encontró empleado con email {test_email}")
            print(f"   Email hash buscado: {email_hash}")

            # Listar todos los empleados
            all_employees = session.query(Employee).all()
            print(f"\n   Empleados encontrados en BD: {len(all_employees)}")
            for emp in all_employees:
                print(f"   - ID: {emp.id}, Email: {emp.email}, Hash: {emp.email_hash}")
            return False

        print("✓ Empleado encontrado:")
        print(f"  ID:        {employee.id}")
        print(f"  Nombre:    {employee.name}")
        print(f"  Email:     {employee.email}")
        print(f"  Email encrypted: {employee.email_encrypted[:50]}...")
        print(f"  Email hash: {employee.email_hash}")
        print(f"  Auth hash:  {employee.auth_hash}")
        print(f"  Rol:       {employee.role}")
        print(f"  Activo:    {employee.is_active}")

        return True


def test_password_verification():
    """Test password verification for existing employee."""
    print_separator("PRUEBA 4: Verificación de Contraseña")

    with get_session() as session:
        test_email = "admin@cafeteria.test"
        test_password = "ChangeMe!123"  # nosec B105

        email_hash = hash_identifier(test_email)
        employee = session.query(Employee).filter(Employee.email_hash == email_hash).first()

        if not employee:
            print("❌ No se encontró empleado")
            return False

        print(f"Email ingresado:  {test_email}")
        print(f"Email del objeto: {employee.email}")
        print(f"Password:         {test_password}")

        # Verificar usando el método del modelo
        is_valid = employee.verify_password(test_password)
        print(f"\n✓ employee.verify_password(): {is_valid}")

        # Verificar manualmente
        manual_hash = hash_credentials(employee.email, test_password)
        manual_valid = manual_hash == employee.auth_hash
        print(f"✓ Verificación manual:        {manual_valid}")

        if not is_valid:
            print("\n❌ PROBLEMA ENCONTRADO:")
            print(f"   Hash esperado: {employee.auth_hash}")
            print(f"   Hash generado: {manual_hash}")

            # Intentar re-generar el hash con el email desencriptado
            decrypted_email = employee.email
            test_hash = hash_credentials(decrypted_email, test_password)
            print(f"\n   Email desencriptado: {decrypted_email}")
            print(f"   Hash con email desencriptado: {test_hash}")
            print(f"   ¿Match? {test_hash == employee.auth_hash}")

        return is_valid


def test_full_login_simulation():
    """Simulate full login flow."""
    print_separator("PRUEBA 5: Simulación de Login Completo")

    test_email = "admin@cafeteria.test"
    test_password = "ChangeMe!123"  # nosec B105

    print("Intentando login con:")
    print(f"  Email:    {test_email}")
    print(f"  Password: {test_password}")

    with get_session() as db:
        # Step 1: Hash the email
        email_hash = hash_identifier(test_email)
        print("\nPaso 1: Hash del email")
        print(f"  Email hash: {email_hash}")

        # Step 2: Find employee
        employee = db.query(Employee).filter(Employee.email_hash == email_hash).first()

        if not employee:
            print("\n❌ Paso 2 FALLÓ: No se encontró empleado")
            return False

        print("\n✓ Paso 2: Empleado encontrado")
        print(f"  ID: {employee.id}, Nombre: {employee.name}")

        # Step 3: Verify password
        if not employee.verify_password(test_password):
            print("\n❌ Paso 3 FALLÓ: Password inválido")
            return False

        print("\n✓ Paso 3: Password verificado correctamente")

        # Step 4: Check active status
        if not employee.is_active:
            print("\n❌ Paso 4 FALLÓ: Cuenta desactivada")
            return False

        print("\n✓ Paso 4: Cuenta activa")

        print("\n✓✓✓ LOGIN EXITOSO ✓✓✓")
        print(f"  Empleado: {employee.name}")
        print(f"  Rol: {employee.role}")
        return True


def test_all_employees_login():
    """Test login for all seeded employees."""
    print_separator("PRUEBA 6: Login de Todos los Empleados Seed")

    test_users = [
        ("admin@cafeteria.test", "Admin General", "system"),
        ("admin.roles@cafeteria.test", "Admin Roles", "admin"),
        ("juan.mesero@cafeteria.test", "Juan Mesero", "waiter"),
        ("maria.mesera@cafeteria.test", "Maria Mesera", "waiter"),
        ("pedro.mesero@cafeteria.test", "Pedro Mesero", "waiter"),
        ("carlos.chef@cafeteria.test", "Carlos Chef", "chef"),
        ("ana.chef@cafeteria.test", "Ana Chef", "chef"),
        ("laura.cajera@cafeteria.test", "Laura Cajera", "cashier"),
        ("roberto.cajero@cafeteria.test", "Roberto Cajero", "cashier"),
    ]

    password = os.getenv("SEED_EMPLOYEE_PASSWORD", "ChangeMe!123")
    print(f"Password de prueba: {password}\n")

    results = []
    with get_session() as db:
        for email, expected_name, expected_role in test_users:
            email_hash = hash_identifier(email)
            employee = db.query(Employee).filter(Employee.email_hash == email_hash).first()

            if not employee:
                results.append((email, False, "No encontrado"))
                continue

            if employee.name != expected_name:
                results.append((email, False, f"Nombre incorrecto: {employee.name}"))
                continue

            if employee.role != expected_role:
                results.append((email, False, f"Rol incorrecto: {employee.role}"))
                continue

            if not employee.verify_password(password):
                results.append((email, False, "Password inválido"))
                continue

            results.append((email, True, "OK"))

    # Print results
    success_count = sum(1 for _, success, _ in results if success)
    print(f"Resultados: {success_count}/{len(results)} exitosos\n")

    for email, success, message in results:
        status = "✓" if success else "❌"
        print(f"{status} {email:40} - {message}")

    return success_count == len(results)


def main():
    """Run all tests."""
    print("\n" + "█" * 80)
    print("  DIAGNÓSTICO DE AUTENTICACIÓN - PRONTO APP")
    print("█" * 80)

    try:
        test_encryption()
        test_hashing()

        if not test_employee_creation():
            print("\n" + "!" * 80)
            print("  ADVERTENCIA: No se encontraron empleados en la base de datos")
            print("  Ejecuta: python pronto-libs/src/pronto_shared/services/seed.py")
            print("!" * 80)
            return

        test_password_verification()
        test_full_login_simulation()
        test_all_employees_login()

        print_separator("RESUMEN")
        print("Si todas las pruebas pasaron ✓, el sistema de autenticación está OK")
        print("Si alguna falló ❌, revisa los detalles arriba para diagnosticar")

    except Exception as e:
        print("\n❌ ERROR DURANTE LAS PRUEBAS:")
        print(f"   {type(e).__name__}: {e}")
        traceback.print_exc()


if __name__ == "__main__":
    main()
