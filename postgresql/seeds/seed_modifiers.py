#!/usr/bin/env python3
"""
Script CRUD para Aditamientos/Modificadores (Modifiers).

Funciones:
- Agregar nuevos modificadores
- Modificar modificadores existentes
- Eliminar modificadores
- Listar modificadores

Uso:
    python seeds/seed_modifiers.py --action add --name "Queso Extra" --group "Queso Extra" --price 1.50
    python seeds/seed_modifiers.py --action list
    python seeds/seed_modifiers.py --action update --id 1 --price 2.00
    python seeds/seed_modifiers.py --action delete --id 1
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
from shared.models import Base, Modifier, ModifierGroup


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


def list_modifiers(session, group_name=None):
    """Listar todos los modificadores."""
    query = select(Modifier)
    if group_name:
        group = session.execute(
            select(ModifierGroup).where(ModifierGroup.name == group_name)
        ).scalar_one_or_none()
        if group:
            query = query.where(Modifier.group_id == group.id)
        else:
            print(f"Grupo '{group_name}' no encontrado.")
            return

    modifiers = session.execute(query).scalars().all()

    print(f"\n{'=' * 80}")
    print(f"ADITAMENTOS/MODIFICADORES ({len(modifiers)} total)")
    print(f"{'=' * 80}")

    for modifier in modifiers:
        group = session.get(ModifierGroup, modifier.group_id)
        print(f"\nID: {modifier.id}")
        print(f"  Nombre: {modifier.name}")
        print(f"  Grupo: {group.name if group else 'N/A'}")
        print(f"  Ajuste de precio: ${modifier.price_adjustment}")
        print(f"  Orden: {modifier.display_order}")

    return modifiers


def add_modifier(
    session,
    name: str,
    group_name: str,
    price_adjustment: Decimal = Decimal("0.00"),
    display_order: int = None,
):
    """Agregar un nuevo modificador."""
    group = session.execute(
        select(ModifierGroup).where(ModifierGroup.name == group_name)
    ).scalar_one_or_none()

    if not group:
        print(f"Error: Grupo '{group_name}' no encontrado.")
        print("Grupos disponibles:")
        groups = session.execute(select(ModifierGroup)).scalars().all()
        for g in groups:
            print(f"  - {g.name}")
        return None

    existing = session.execute(
        select(Modifier).where(Modifier.name == name, Modifier.group_id == group.id)
    ).scalar_one_or_none()

    if existing:
        print(f"Modificador '{name}' ya existe en grupo '{group_name}'.")
        print(f"  ID: {existing.id}")
        return existing

    if display_order is None:
        max_order = session.execute(
            select(Modifier.display_order)
            .where(Modifier.group_id == group.id)
            .order_by(Modifier.display_order.desc())
        ).scalar_one_or_none()
        display_order = (max_order or 0) + 1

    modifier = Modifier(
        name=name,
        group_id=group.id,
        price_adjustment=price_adjustment,
        display_order=display_order,
    )
    session.add(modifier)
    session.flush()
    print(f"Modificador '{name}' agregado exitosamente.")
    print(f"  ID: {modifier.id}")
    print(f"  Grupo: {group_name}")
    print(f"  Ajuste de precio: ${price_adjustment}")
    print(f"  Orden: {display_order}")
    return modifier


def update_modifier(
    session,
    modifier_id: int,
    name: str = None,
    price_adjustment: Decimal = None,
    display_order: int = None,
):
    """Modificar un modificador existente."""
    modifier = session.get(Modifier, modifier_id)
    if not modifier:
        print(f"Error: Modificador con ID {modifier_id} no encontrado.")
        return None

    changes = []
    if name is not None and name != modifier.name:
        modifier.name = name
        changes.append(f"Nombre: {name}")

    if price_adjustment is not None and price_adjustment != modifier.price_adjustment:
        modifier.price_adjustment = price_adjustment
        changes.append(f"Precio: ${price_adjustment}")

    if display_order is not None and display_order != modifier.display_order:
        modifier.display_order = display_order
        changes.append(f"Orden: {display_order}")

    if changes:
        print(f"Modificador ID {modifier_id} actualizado:")
        for change in changes:
            print(f"  - {change}")
    else:
        print(f"No se detectaron cambios para modificador ID {modifier_id}.")

    return modifier


def delete_modifier(session, modifier_id: int):
    """Eliminar un modificador."""
    modifier = session.get(Modifier, modifier_id)
    if not modifier:
        print(f"Error: Modificador con ID {modifier_id} no encontrado.")
        return False

    modifier_name = modifier.name
    session.delete(modifier)
    print(f"Modificador '{modifier_name}' (ID {modifier_id}) eliminado exitosamente.")
    return True


def search_modifiers(session, search_term: str):
    """Buscar modificadores por nombre."""
    modifiers = (
        session.execute(select(Modifier).where(Modifier.name.ilike(f"%{search_term}%")))
        .scalars()
        .all()
    )

    print(f"\nResultados para '{search_term}' ({len(modifiers)} encontrados):")
    for modifier in modifiers:
        group = session.get(ModifierGroup, modifier.group_id)
        print(
            f"  - {modifier.name} ({group.name if group else 'N/A'}) - ${modifier.price_adjustment}"
        )

    return modifiers


def main():
    parser = argparse.ArgumentParser(description="Gestionar aditamentos/modificadores")
    parser.add_argument(
        "--action",
        choices=["list", "add", "update", "delete", "search"],
        required=True,
        help="Acción a realizar",
    )
    parser.add_argument(
        "--id", type=int, help="ID del modificador (para update/delete)"
    )
    parser.add_argument("--name", help="Nombre del modificador")
    parser.add_argument("--group", help="Nombre del grupo de modificadores")
    parser.add_argument("--price", type=float, help="Ajuste de precio")
    parser.add_argument("--order", type=int, help="Orden de visualización")
    parser.add_argument("--search", help="Término de búsqueda")
    parser.add_argument("--group-filter", help="Filtrar por grupo")

    args = parser.parse_args()

    init_database()

    with get_session() as session:
        if args.action == "list":
            list_modifiers(session, args.group_filter)
        elif args.action == "search":
            if not args.search:
                print("Error: Debes especificar --search para la búsqueda.")
                sys.exit(1)
            search_modifiers(session, args.search)
        elif args.action == "add":
            if not args.name or not args.group:
                print("Error: --name y --group son requeridos para agregar.")
                sys.exit(1)
            add_modifier(
                session,
                name=args.name,
                group_name=args.group,
                price_adjustment=Decimal(str(args.price))
                if args.price
                else Decimal("0.00"),
                display_order=args.order,
            )
            session.commit()
        elif args.action == "update":
            if not args.id:
                print("Error: --id es requerido para actualizar.")
                sys.exit(1)
            update_modifier(
                session,
                modifier_id=args.id,
                name=args.name,
                price_adjustment=Decimal(str(args.price)) if args.price else None,
                display_order=args.order,
            )
            session.commit()
        elif args.action == "delete":
            if not args.id:
                print("Error: --id es requerido para eliminar.")
                sys.exit(1)
            delete_modifier(session, args.id)
            session.commit()


if __name__ == "__main__":
    main()
