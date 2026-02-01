#!/usr/bin/env python3
"""
Script CRUD para Empleados (Employees).

Funciones:
- Agregar nuevos empleados
- Modificar empleados existentes
- Eliminar empleados
- Listar empleados
- Asignar roles

Uso:
    python seeds/seed_employees.py --action add --name "Juan Pérez" --email "juan@email.com" --role "waiter"
    python seeds/seed_employees.py --action list
    python seeds/seed_employees.py --action update --id 1 --role "chef"
    python seeds/seed_employees.py --action delete --id 1
"""

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, str(Path(__file__).parent.parent / "build"))

import json as json_lib
from sqlalchemy import select

from shared.config import load_config
from shared.db import get_session, init_db, init_engine
from shared.models import Base, Employee
from shared.security import hash_credentials, hash_identifier
from shared.validation import validate_password


def load_env():
    """Cargar variables de entorno."""
    project_root = Path(__file__).parent.parent
    env_file = project_root / "config" / "general.env"
    secrets_file = project_root / "config" / "secrets.env"

    if env_file.exists():
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if line and "=" in line and not line.startswith("#"):
                    key, value = line.split("=", 1)
                    os.environ.setdefault(key.strip(), value.strip())

    if secrets_file.exists():
        with open(secrets_file) as f:
            for line in f:
                line = line.strip()
                if line and "=" in line and not line.startswith("#"):
                    key, value = line.split("=", 1)
                    os.environ.setdefault(key.strip(), value.strip())


def init_database():
    """Inicializar conexión a la base de datos."""
    load_env()
    config = load_config("seed_script")
    init_engine(config)
    init_db(Base.metadata)


def get_default_password():
    """Obtener contraseña por defecto."""
    return os.getenv("SEED_EMPLOYEE_PASSWORD", "ChangeMe!123")


def _get_scopes_for_role(role: str):
    """Obtener los scopes permitidos según el rol."""
    scopes_map = {
        "super_admin": ["system", "admin", "waiter", "chef", "cashier"],
        "admin": ["admin", "waiter", "chef", "cashier"],
        "system": ["system", "admin", "waiter", "chef", "cashier"],
        "waiter": ["waiter", "cashier"],
        "chef": ["chef"],
        "cashier": ["cashier", "waiter"],
        "admin_roles": ["admin"],
        "content_manager": ["admin"],
    }
    return scopes_map.get(role, [])


def list_employees(session, role_filter=None):
    """Listar todos los empleados."""
    query = select(Employee)
    if role_filter:
        query = query.where(Employee.role == role_filter)

    employees = session.execute(query).scalars().all()

    print(f"\n{'=' * 80}")
    print(f"EMPLEADOS ({len(employees)} total)")
    print(f"{'=' * 80}")

    for employee in employees:
        scopes = employee.get_scopes() if hasattr(employee, "get_scopes") else []
        print(f"\nID: {employee.id}")
        print(f"  Nombre: {employee.name}")
        print(f"  Email: {employee.email}")
        print(f"  Rol: {employee.role}")
        print(f"  Scopes: {', '.join(scopes) if scopes else 'N/A'}")
        print(f"  Roles adicionales: {employee.additional_roles or 'Ninguno'}")
        print(f"  Activo: {'Sí' if employee.is_active else 'No'}")
        print(f"  Creado: {employee.created_at or 'N/A'}")

    return employees


def add_employee(
    session,
    name: str,
    email: str,
    role: str,
    password: str = None,
    additional_roles: list = None,
):
    """Agregar un nuevo empleado."""
    if not email:
        print("Error: El email es requerido.")
        return None

    email_hash = hash_identifier(email)

    existing = session.execute(
        select(Employee).where(Employee.email_hash == email_hash)
    ).scalar_one_or_none()

    if existing:
        print(f"Empleado con email '{email}' ya existe.")
        print(f"  ID: {existing.id}")
        print(f"  Nombre: {existing.name}")
        return existing

    if password is None:
        password = get_default_password()

    validate_password(password)
    auth_hash = hash_credentials(email, password)

    scopes = _get_scopes_for_role(role)

    employee = Employee(
        name=name,
        email=email,
        email_hash=email_hash,
        auth_hash=auth_hash,
        role=role,
        allow_scopes=json_lib.dumps(scopes),
        is_active=True,
    )

    if additional_roles:
        employee.additional_roles = json_lib.dumps(additional_roles)

    session.add(employee)
    session.flush()
    print(f"Empleado '{name}' agregado exitosamente.")
    print(f"  ID: {employee.id}")
    print(f"  Email: {email}")
    print(f"  Rol: {role}")
    print(f"  Scopes: {', '.join(scopes)}")
    return employee


def update_employee(
    session,
    employee_id: int,
    name: str = None,
    email: str = None,
    role: str = None,
    additional_roles: list = None,
    is_active: bool = None,
    reset_password: bool = False,
):
    """Modificar un empleado existente."""
    employee = session.get(Employee, employee_id)
    if not employee:
        print(f"Error: Empleado con ID {employee_id} no encontrado.")
        return None

    changes = []
    if name is not None and name != employee.name:
        employee.name = name
        changes.append(f"Nombre: {name}")

    if email is not None and email != employee.email:
        employee.email = email
        employee.email_hash = hash_identifier(email)
        changes.append(f"Email: {email}")

    if role is not None and role != employee.role:
        employee.role = role
        scopes = _get_scopes_for_role(role)
        employee.allow_scopes = json_lib.dumps(scopes)
        changes.append(f"Rol: {role}")
        changes.append(f"Scopes actualizados: {', '.join(scopes)}")

    if additional_roles is not None:
        employee.additional_roles = json_lib.dumps(additional_roles)
        changes.append(f"Roles adicionales: {additional_roles}")

    if is_active is not None and is_active != employee.is_active:
        employee.is_active = is_active
        changes.append(f"Activo: {is_active}")

    if reset_password:
        password = get_default_password()
        validate_password(password)
        employee.auth_hash = hash_credentials(employee.email, password)
        changes.append("Contraseña reseteada")

    if changes:
        print(f"Empleado ID {employee_id} actualizado:")
        for change in changes:
            print(f"  - {change}")
    else:
        print(f"No se detectaron cambios para empleado ID {employee_id}.")

    return employee


def delete_employee(session, employee_id: int):
    """Eliminar (desactivar) un empleado."""
    employee = session.get(Employee, employee_id)
    if not employee:
        print(f"Error: Empleado con ID {employee_id} no encontrado.")
        return False

    employee_name = employee.name
    employee.is_active = False
    print(f"Empleado '{employee_name}' (ID {employee_id}) desactivado exitosamente.")
    return True


def search_employees(session, search_term: str):
    """Buscar empleados por nombre o email."""
    employees = (
        session.execute(
            select(Employee).where(
                (Employee.name.ilike(f"%{search_term}%"))
                | (Employee.email.ilike(f"%{search_term}%"))
            )
        )
        .scalars()
        .all()
    )

    print(f"\nResultados para '{search_term}' ({len(employees)} encontrados):")
    for employee in employees:
        print(f"  - {employee.name} ({employee.role}) - {employee.email}")

    return employees


def bulk_add_employees(session, employees_data: list):
    """Agregar múltiples empleados."""
    created = 0
    password = get_default_password()
    validate_password(password)

    for data in employees_data:
        email = data["email"]
        email_hash = hash_identifier(email)

        existing = session.execute(
            select(Employee).where(Employee.email_hash == email_hash)
        ).scalar_one_or_none()

        if existing:
            continue

        role = data.get("role", "waiter")
        scopes = _get_scopes_for_role(role)

        employee = Employee(
            name=data["name"],
            email=email,
            email_hash=email_hash,
            auth_hash=hash_credentials(email, password),
            role=role,
            allow_scopes=json_lib.dumps(scopes),
            is_active=True,
        )

        if data.get("additional_roles"):
            employee.additional_roles = json_lib.dumps(data["additional_roles"])

        session.add(employee)
        created += 1

    print(f"{created} empleados agregados de {len(employees_data)} datos.")
    return created


def main():
    parser = argparse.ArgumentParser(description="Gestionar empleados")
    parser.add_argument(
        "--action",
        choices=["list", "add", "update", "delete", "search", "bulk"],
        required=True,
        help="Acción a realizar",
    )
    parser.add_argument("--id", type=int, help="ID del empleado (para update/delete)")
    parser.add_argument("--name", help="Nombre del empleado")
    parser.add_argument("--email", help="Email del empleado")
    parser.add_argument(
        "--role", help="Rol del empleado (waiter, chef, cashier, admin, etc.)"
    )
    parser.add_argument("--search", help="Término de búsqueda")
    parser.add_argument(
        "--reset-password", action="store_true", help="Resetear contraseña"
    )
    parser.add_argument("--inactive", action="store_true", help="Empleado inactivo")
    parser.add_argument("--role-filter", help="Filtrar por rol")

    args = parser.parse_args()

    init_database()

    with get_session() as session:
        if args.action == "list":
            list_employees(session, args.role_filter)
        elif args.action == "search":
            if not args.search:
                print("Error: Debes especificar --search para la búsqueda.")
                sys.exit(1)
            search_employees(session, args.search)
        elif args.action == "add":
            if not args.name or not args.email or not args.role:
                print("Error: --name, --email y --role son requeridos para agregar.")
                sys.exit(1)
            add_employee(session, args.name, args.email, args.role)
            session.commit()
        elif args.action == "update":
            if not args.id:
                print("Error: --id es requerido para actualizar.")
                sys.exit(1)
            update_employee(
                session,
                employee_id=args.id,
                name=args.name,
                email=args.email,
                role=args.role,
                is_active=not args.inactive,
                reset_password=args.reset_password,
            )
            session.commit()
        elif args.action == "delete":
            if not args.id:
                print("Error: --id es requerido para eliminar.")
                sys.exit(1)
            delete_employee(session, args.id)
            session.commit()


if __name__ == "__main__":
    main()
