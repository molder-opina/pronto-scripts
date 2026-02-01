#!/usr/bin/env python3
"""
Script CRUD para Clientes (Customers).

Funciones:
- Agregar nuevos clientes
- Modificar clientes existentes
- Eliminar clientes
- Listar clientes

Uso:
    python seeds/seed_customers.py --action add --name "Juan Pérez" --email "juan@email.com" --phone "+34600000000"
    python seeds/seed_customers.py --action list
    python seeds/seed_customers.py --action update --id 1 --name "Juan García"
    python seeds/seed_customers.py --action delete --id 1
"""

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, str(Path(__file__).parent.parent / "build"))

from sqlalchemy import select

from shared.config import load_config
from shared.db import get_session, init_db, init_engine
from shared.models import Base, Customer
from shared.security import hash_identifier


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


def list_customers(session, limit=100, offset=0):
    """Listar todos los clientes."""
    customers = (
        session.execute(select(Customer).limit(limit).offset(offset)).scalars().all()
    )

    print(f"\n{'=' * 80}")
    print(f"CLIENTES ({len(customers)} mostrados de total)")
    print(f"{'=' * 80}")

    for customer in customers:
        print(f"\nID: {customer.id}")
        print(f"  Nombre: {customer.name}")
        print(f"  Email: {customer.email}")
        print(f"  Teléfono: {customer.phone or 'N/A'}")
        print(
            f"  Email hash: {customer.email_hash[:16]}..."
            if customer.email_hash
            else "  Email hash: N/A"
        )
        print(f"  Creado: {customer.created_at or 'N/A'}")
        print(f"  Actualizado: {customer.updated_at or 'N/A'}")

    return customers


def add_customer(session, name: str, email: str, phone: str = None):
    """Agregar un nuevo cliente."""
    if not email:
        print("Error: El email es requerido.")
        return None

    email_hash = hash_identifier(email)

    existing = session.execute(
        select(Customer).where(Customer.email_hash == email_hash)
    ).scalar_one_or_none()

    if existing:
        print(f"Cliente con email '{email}' ya existe.")
        print(f"  ID: {existing.id}")
        print(f"  Nombre: {existing.name}")
        return existing

    customer = Customer(
        name=name,
        email=email,
        email_hash=email_hash,
        phone=phone,
    )
    session.add(customer)
    session.flush()
    print(f"Cliente '{name}' agregado exitosamente.")
    print(f"  ID: {customer.id}")
    print(f"  Email: {email}")
    print(f"  Teléfono: {phone or 'N/A'}")
    return customer


def update_customer(
    session,
    customer_id: int,
    name: str = None,
    email: str = None,
    phone: str = None,
):
    """Modificar un cliente existente."""
    customer = session.get(Customer, customer_id)
    if not customer:
        print(f"Error: Cliente con ID {customer_id} no encontrado.")
        return None

    changes = []
    if name is not None and name != customer.name:
        customer.name = name
        changes.append(f"Nombre: {name}")

    if email is not None and email != customer.email:
        customer.email = email
        customer.email_hash = hash_identifier(email)
        changes.append(f"Email: {email}")

    if phone is not None and phone != customer.phone:
        customer.phone = phone
        changes.append(f"Teléfono: {phone}")

    if changes:
        print(f"Cliente ID {customer_id} actualizado:")
        for change in changes:
            print(f"  - {change}")
    else:
        print(f"No se detectaron cambios para cliente ID {customer_id}.")

    return customer


def delete_customer(session, customer_id: int):
    """Eliminar un cliente."""
    customer = session.get(Customer, customer_id)
    if not customer:
        print(f"Error: Cliente con ID {customer_id} no encontrado.")
        return False

    customer_name = customer.name
    session.delete(customer)
    print(f"Cliente '{customer_name}' (ID {customer_id}) eliminado exitosamente.")
    return True


def search_customers(session, search_term: str):
    """Buscar clientes por nombre o email."""
    customers = (
        session.execute(
            select(Customer).where(
                (Customer.name.ilike(f"%{search_term}%"))
                | (Customer.email.ilike(f"%{search_term}%"))
            )
        )
        .scalars()
        .all()
    )

    print(f"\nResultados para '{search_term}' ({len(customers)} encontrados):")
    for customer in customers:
        print(f"  - {customer.name} ({customer.email})")

    return customers


def bulk_add_customers(session, customers_data: list):
    """Agregar múltiples clientes."""
    created = 0
    for data in customers_data:
        email_hash = hash_identifier(data["email"])
        existing = session.execute(
            select(Customer).where(Customer.email_hash == email_hash)
        ).scalar_one_or_none()

        if existing:
            continue

        customer = Customer(
            name=data["name"],
            email=data["email"],
            email_hash=email_hash,
            phone=data.get("phone"),
        )
        session.add(customer)
        created += 1

    print(f"{created} clientes agregados de {len(customers_data)} datos.")
    return created


def main():
    parser = argparse.ArgumentParser(description="Gestionar clientes")
    parser.add_argument(
        "--action",
        choices=["list", "add", "update", "delete", "search", "bulk"],
        required=True,
        help="Acción a realizar",
    )
    parser.add_argument("--id", type=int, help="ID del cliente (para update/delete)")
    parser.add_argument("--name", help="Nombre del cliente")
    parser.add_argument("--email", help="Email del cliente")
    parser.add_argument("--phone", help="Teléfono del cliente")
    parser.add_argument("--search", help="Término de búsqueda")
    parser.add_argument("--limit", type=int, default=100, help="Límite de resultados")
    parser.add_argument("--offset", type=int, default=0, help="Offset para paginación")

    args = parser.parse_args()

    init_database()

    with get_session() as session:
        if args.action == "list":
            list_customers(session, args.limit, args.offset)
        elif args.action == "search":
            if not args.search:
                print("Error: Debes especificar --search para la búsqueda.")
                sys.exit(1)
            search_customers(session, args.search)
        elif args.action == "add":
            if not args.name or not args.email:
                print("Error: --name y --email son requeridos para agregar.")
                sys.exit(1)
            add_customer(session, args.name, args.email, args.phone)
            session.commit()
        elif args.action == "update":
            if not args.id:
                print("Error: --id es requerido para actualizar.")
                sys.exit(1)
            update_customer(
                session,
                customer_id=args.id,
                name=args.name,
                email=args.email,
                phone=args.phone,
            )
            session.commit()
        elif args.action == "delete":
            if not args.id:
                print("Error: --id es requerido para eliminar.")
                sys.exit(1)
            delete_customer(session, args.id)
            session.commit()


if __name__ == "__main__":
    main()
