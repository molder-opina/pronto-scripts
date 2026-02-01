#!/usr/bin/env python3
"""
Script CRUD para Productos (MenuItems) del menú.

Funciones:
- Agregar nuevos productos
- Modificar productos existentes
- Eliminar productos
- Listar productos

Uso:
    python seeds/seed_products.py --action add --name "Hamburguesa Clásica" --price 7.50 --category "Hamburguesas"
    python seeds/seed_products.py --action list
    python seeds/seed_products.py --action update --id 1 --price 8.00
    python seeds/seed_products.py --action delete --id 1
"""

import argparse
import os
import sys
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, str(Path(__file__).parent.parent / "build"))

from sqlalchemy import select

from shared.config import load_config
from shared.db import get_session, init_db, init_engine
from shared.models import Base, MenuCategory, MenuItem


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


def list_products(session, category_name=None):
    """Listar todos los productos."""
    query = select(MenuItem)
    if category_name:
        category = session.execute(
            select(MenuCategory).where(MenuCategory.name == category_name)
        ).scalar_one_or_none()
        if category:
            query = query.where(MenuItem.category_id == category.id)
        else:
            print(f"Categoria '{category_name}' no encontrada.")
            return

    products = session.execute(query).scalars().all()

    print("")
    print("=" * 80)
    print(f"PRODUCTOS ({len(products)} total)")
    print("=" * 80)

    for product in products:
        category = session.get(MenuCategory, product.category_id)
        print(f"\nID: {product.id}")
        print(f"  Nombre: {product.name}")
        print(f"  Categoría: {category.name if category else 'N/A'}")
        print(f"  Precio: ${product.price}")
        print(f"  Descripción: {product.description or 'N/A'}")
        print(f"  Tiempo prep: {product.preparation_time_minutes} min")
        print(f"  Disponible: {'Sí' if product.is_available else 'No'}")
        print(f"  Quick serve: {'Sí' if product.is_quick_serve else 'No'}")

    return products


def add_product(
    session,
    name: str,
    price: Decimal,
    category_name: str,
    description: str = None,
    preparation_time_minutes: int = 15,
    is_available: bool = True,
    is_quick_serve: bool = False,
    is_breakfast_recommended: bool = False,
    is_afternoon_recommended: bool = False,
    is_night_recommended: bool = False,
):
    """Agregar un nuevo producto."""
    category = session.execute(
        select(MenuCategory).where(MenuCategory.name == category_name)
    ).scalar_one_or_none()

    if not category:
        print(f"Error: Categoría '{category_name}' no encontrada.")
        print("Categorías disponibles:")
        categories = session.execute(select(MenuCategory)).scalars().all()
        for cat in categories:
            print(f"  - {cat.name}")
        return None

    existing = session.execute(
        select(MenuItem).where(
            MenuItem.name == name, MenuItem.category_id == category.id
        )
    ).scalar_one_or_none()

    if existing:
        print(f"Producto '{name}' ya existe en categoria '{category_name}'.")

    product = MenuItem(
        name=name,
        price=price,
        category_id=category.id,
        description=description,
        preparation_time_minutes=preparation_time_minutes,
        is_available=is_available,
        is_quick_serve=is_quick_serve,
        is_breakfast_recommended=is_breakfast_recommended,
        is_afternoon_recommended=is_afternoon_recommended,
        is_night_recommended=is_night_recommended,
    )
    session.add(product)
    session.flush()
    print(f"Producto '{name}' agregado exitosamente.")
    print(f"  ID: {product.id}")
    print(f"  Categoría: {category_name}")
    print(f"  Precio: ${price}")
    return product


def update_product(
    session,
    product_id: int,
    name: str = None,
    price: Decimal = None,
    description: str = None,
    preparation_time_minutes: int = None,
    is_available: bool = None,
    is_quick_serve: bool = None,
):
    """Modificar un producto existente."""
    product = session.get(MenuItem, product_id)
    if not product:
        print(f"Error: Producto con ID {product_id} no encontrado.")
        return None

    changes = []
    if name is not None and name != product.name:
        product.name = name
        changes.append(f"Nombre: {name}")
    if price is not None and price != product.price:
        product.price = price
        changes.append(f"Precio: ${price}")
    if description is not None and description != product.description:
        product.description = description
        changes.append(f"Descripción: {description}")
    if (
        preparation_time_minutes is not None
        and preparation_time_minutes != product.preparation_time_minutes
    ):
        product.preparation_time_minutes = preparation_time_minutes
        changes.append(f"Tiempo prep: {preparation_time_minutes} min")
    if is_available is not None and is_available != product.is_available:
        product.is_available = is_available
        changes.append(f"Disponible: {is_available}")
    if is_quick_serve is not None and is_quick_serve != product.is_quick_serve:
        product.is_quick_serve = is_quick_serve
        changes.append(f"Quick serve: {is_quick_serve}")

    if changes:
        print(f"Producto ID {product_id} actualizado:")
        for change in changes:
            print(f"  - {change}")
    else:
        print(f"No se detectaron cambios para producto ID {product_id}.")

    return product


def delete_product(session, product_id: int):
    """Eliminar un producto."""
    product = session.get(MenuItem, product_id)
    if not product:
        print(f"Error: Producto con ID {product_id} no encontrado.")
        return False

    product_name = product.name
    session.delete(product)
    print(f"Producto '{product_name}' (ID {product_id}) eliminado exitosamente.")
    return True


def search_products(session, search_term: str):
    """Buscar productos por nombre."""
    products = (
        session.execute(select(MenuItem).where(MenuItem.name.ilike(f"%{search_term}%")))
        .scalars()
        .all()
    )

    print(f"\nResultados para '{search_term}' ({len(products)} encontrados):")
    for product in products:
        category = session.get(MenuCategory, product.category_id)
        print(
            f"  - {product.name} ({category.name if category else 'N/A'}) - ${product.price}"
        )

    return products


def main():
    parser = argparse.ArgumentParser(description="Gestionar productos del menú")
    parser.add_argument(
        "--action",
        choices=["list", "add", "update", "delete", "search"],
        required=True,
        help="Acción a realizar",
    )
    parser.add_argument("--id", type=int, help="ID del producto (para update/delete)")
    parser.add_argument("--name", help="Nombre del producto")
    parser.add_argument("--price", type=float, help="Precio del producto")
    parser.add_argument("--category", help="Nombre de la categoría")
    parser.add_argument("--description", help="Descripción del producto")
    parser.add_argument(
        "--prep-time", type=int, help="Tiempo de preparación en minutos"
    )
    parser.add_argument(
        "--available", type=bool, help="Producto disponible (true/false)"
    )
    parser.add_argument("--quick-serve", type=bool, help="Es quick serve (true/false)")
    parser.add_argument("--search", help="Término de búsqueda")
    parser.add_argument("--category-filter", help="Filtrar por categoría (para list)")

    args = parser.parse_args()

    init_database()

    with get_session() as session:
        if args.action == "list":
            list_products(session, args.category_filter)
        elif args.action == "search":
            if not args.search:
                print("Error: Debes especificar --search para la búsqueda.")
                sys.exit(1)
            search_products(session, args.search)
        elif args.action == "add":
            if not args.name or not args.price or not args.category:
                print(
                    "Error: --name, --price y --category son requeridos para agregar."
                )
                sys.exit(1)
            add_product(
                session,
                name=args.name,
                price=Decimal(str(args.price)),
                category_name=args.category,
                description=args.description,
                preparation_time_minutes=args.prep_time or 15,
                is_available=args.available if args.available is not None else True,
                is_quick_serve=args.quick_serve
                if args.quick_serve is not None
                else False,
            )
            session.commit()
        elif args.action == "update":
            if not args.id:
                print("Error: --id es requerido para actualizar.")
                sys.exit(1)
            update_product(
                session,
                product_id=args.id,
                name=args.name,
                price=Decimal(str(args.price)) if args.price else None,
                description=args.description,
                preparation_time_minutes=args.prep_time,
                is_available=args.available,
                is_quick_serve=args.quick_serve,
            )
            session.commit()
        elif args.action == "delete":
            if not args.id:
                print("Error: --id es requerido para eliminar.")
                sys.exit(1)
            delete_product(session, args.id)
            session.commit()


if __name__ == "__main__":
    main()
