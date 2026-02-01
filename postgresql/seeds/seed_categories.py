#!/usr/bin/env python3
"""
Script CRUD para Categorías del Menú (MenuCategories).

Funciones:
- Agregar nuevas categorías
- Modificar categorías existentes
- Eliminar categorías
- Listar categorías

Uso:
    python seeds/seed_categories.py --action add --name "Postres" --description "Dulces y pasteles" --order 7
    python seeds/seed_categories.py --action list
    python seeds/seed_categories.py --action update --id 1 --name "Bebidas"
    python seeds/seed_categories.py --action delete --id 1
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
from shared.models import Base, MenuCategory


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


def list_categories(session):
    """Listar todas las categorías."""
    categories = (
        session.execute(select(MenuCategory).order_by(MenuCategory.display_order))
        .scalars()
        .all()
    )

    print(f"\n{'=' * 80}")
    print(f"CATEGORÍAS ({len(categories)} total)")
    print(f"{'=' * 80}")

    for category in categories:
        print(f"\nID: {category.id}")
        print(f"  Nombre: {category.name}")
        print(f"  Descripción: {category.description or 'N/A'}")
        print(f"  Orden: {category.display_order}")
        print(f"  Activa: {'Sí' if category.is_active else 'No'}")

    return categories


def add_category(
    session,
    name: str,
    description: str = None,
    display_order: int = None,
    is_active: bool = True,
):
    """Agregar una nueva categoría."""
    existing = session.execute(
        select(MenuCategory).where(MenuCategory.name == name)
    ).scalar_one_or_none()

    if existing:
        print(f"Categoría '{name}' ya existe.")
        print(f"  ID: {existing.id}")
        return existing

    if display_order is None:
        max_order = session.execute(
            select(MenuCategory.display_order).order_by(
                MenuCategory.display_order.desc()
            )
        ).scalar_one_or_none()
        display_order = (max_order or 0) + 1

    category = MenuCategory(
        name=name,
        description=description,
        display_order=display_order,
        is_active=is_active,
    )
    session.add(category)
    session.flush()
    print(f"Categoría '{name}' agregada exitosamente.")
    print(f"  ID: {category.id}")
    print(f"  Descripción: {description or 'N/A'}")
    print(f"  Orden: {display_order}")
    return category


def update_category(
    session,
    category_id: int,
    name: str = None,
    description: str = None,
    display_order: int = None,
    is_active: bool = None,
):
    """Modificar una categoría existente."""
    category = session.get(MenuCategory, category_id)
    if not category:
        print(f"Error: Categoría con ID {category_id} no encontrada.")
        return None

    changes = []
    if name is not None and name != category.name:
        category.name = name
        changes.append(f"Nombre: {name}")

    if description is not None and description != category.description:
        category.description = description
        changes.append(f"Descripción: {description}")

    if display_order is not None and display_order != category.display_order:
        category.display_order = display_order
        changes.append(f"Orden: {display_order}")

    if is_active is not None and is_active != category.is_active:
        category.is_active = is_active
        changes.append(f"Activa: {is_active}")

    if changes:
        print(f"Categoría ID {category_id} actualizada:")
        for change in changes:
            print(f"  - {change}")
    else:
        print(f"No se detectaron cambios para categoría ID {category_id}.")

    return category


def delete_category(session, category_id: int):
    """Eliminar una categoría."""
    category = session.get(MenuCategory, category_id)
    if not category:
        print(f"Error: Categoría con ID {category_id} no encontrada.")
        return False

    category_name = category.name
    session.delete(category)
    print(f"Categoría '{category_name}' (ID {category_id}) eliminada exitosamente.")
    return True


def reorder_categories(session, order_list: list):
    """Reordenar categorías."""
    for idx, category_id in enumerate(order_list, start=1):
        category = session.get(MenuCategory, category_id)
        if category:
            category.display_order = idx

    print(f"{len(order_list)} categorías reordenadas.")
    return True


def main():
    parser = argparse.ArgumentParser(description="Gestionar categorías del menú")
    parser.add_argument(
        "--action",
        choices=["list", "add", "update", "delete", "reorder"],
        required=True,
        help="Acción a realizar",
    )
    parser.add_argument(
        "--id", type=int, help="ID de la categoría (para update/delete)"
    )
    parser.add_argument("--name", help="Nombre de la categoría")
    parser.add_argument("--description", help="Descripción de la categoría")
    parser.add_argument("--order", type=int, help="Orden de visualización")
    parser.add_argument("--inactive", action="store_true", help="Categoría inactiva")
    parser.add_argument(
        "--order-list", nargs="+", type=int, help="Lista de IDs para reordenar"
    )

    args = parser.parse_args()

    init_database()

    with get_session() as session:
        if args.action == "list":
            list_categories(session)
        elif args.action == "add":
            if not args.name:
                print("Error: --name es requerido para agregar.")
                sys.exit(1)
            add_category(
                session,
                name=args.name,
                description=args.description,
                display_order=args.order,
                is_active=not args.inactive,
            )
            session.commit()
        elif args.action == "update":
            if not args.id:
                print("Error: --id es requerido para actualizar.")
                sys.exit(1)
            update_category(
                session,
                category_id=args.id,
                name=args.name,
                description=args.description,
                display_order=args.order,
                is_active=not args.inactive if args.inactive else None,
            )
            session.commit()
        elif args.action == "delete":
            if not args.id:
                print("Error: --id es requerido para eliminar.")
                sys.exit(1)
            delete_category(session, args.id)
            session.commit()
        elif args.action == "reorder":
            if not args.order_list:
                print("Error: --order-list es requerido para reordenar.")
                sys.exit(1)
            reorder_categories(session, args.order_list)
            session.commit()


if __name__ == "__main__":
    main()
