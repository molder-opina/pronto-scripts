#!/usr/bin/env python3
"""
Script CRUD para Grupos de Modificadores (ModifierGroups).

Funciones:
- Agregar nuevos grupos de modificadores
- Modificar grupos existentes
- Eliminar grupos
- Listar grupos

Uso:
    python seeds/seed_modifier_groups.py --action add --name "Queso Extra" --min 0 --max 3 --required false
    python seeds/seed_modifier_groups.py --action list
    python seeds/seed_modifier_groups.py --action update --id 1 --max 5
    python seeds/seed_modifier_groups.py --action delete --id 1
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
from shared.models import Base, ModifierGroup


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


def list_modifier_groups(session):
    """Listar todos los grupos de modificadores."""
    groups = (
        session.execute(select(ModifierGroup).order_by(ModifierGroup.display_order))
        .scalars()
        .all()
    )

    print(f"\n{'=' * 80}")
    print(f"GRUPOS DE MODIFICADORES ({len(groups)} total)")
    print(f"{'=' * 80}")

    for group in groups:
        print(f"\nID: {group.id}")
        print(f"  Nombre: {group.name}")
        print(f"  Descripción: {group.description or 'N/A'}")
        print(f"  Mín selección: {group.min_selection}")
        print(f"  Máx selección: {group.max_selection}")
        print(f"  Obligatorio: {'Sí' if group.is_required else 'No'}")
        print(f"  Orden: {group.display_order}")

    return groups


def add_modifier_group(
    session,
    name: str,
    description: str = None,
    min_selection: int = 0,
    max_selection: int = 1,
    is_required: bool = False,
    display_order: int = None,
):
    """Agregar un nuevo grupo de modificadores."""
    existing = session.execute(
        select(ModifierGroup).where(ModifierGroup.name == name)
    ).scalar_one_or_none()

    if existing:
        print(f"Grupo '{name}' ya existe.")
        print(f"  ID: {existing.id}")
        return existing

    if display_order is None:
        max_order = session.execute(
            select(ModifierGroup.display_order).order_by(
                ModifierGroup.display_order.desc()
            )
        ).scalar_one_or_none()
        display_order = (max_order or 0) + 1

    group = ModifierGroup(
        name=name,
        description=description,
        min_selection=min_selection,
        max_selection=max_selection,
        is_required=is_required,
        display_order=display_order,
    )
    session.add(group)
    session.flush()
    print(f"Grupo '{name}' agregado exitosamente.")
    print(f"  ID: {group.id}")
    print(f"  Mín: {min_selection}, Máx: {max_selection}")
    print(f"  Obligatorio: {'Sí' if is_required else 'No'}")
    return group


def update_modifier_group(
    session,
    group_id: int,
    name: str = None,
    description: str = None,
    min_selection: int = None,
    max_selection: int = None,
    is_required: bool = None,
    display_order: int = None,
):
    """Modificar un grupo de modificadores existente."""
    group = session.get(ModifierGroup, group_id)
    if not group:
        print(f"Error: Grupo con ID {group_id} no encontrado.")
        return None

    changes = []
    if name is not None and name != group.name:
        group.name = name
        changes.append(f"Nombre: {name}")

    if description is not None and description != group.description:
        group.description = description
        changes.append(f"Descripción: {description}")

    if min_selection is not None and min_selection != group.min_selection:
        group.min_selection = min_selection
        changes.append(f"Mín selección: {min_selection}")

    if max_selection is not None and max_selection != group.max_selection:
        group.max_selection = max_selection
        changes.append(f"Máx selección: {max_selection}")

    if is_required is not None and is_required != group.is_required:
        group.is_required = is_required
        changes.append(f"Obligatorio: {is_required}")

    if display_order is not None and display_order != group.display_order:
        group.display_order = display_order
        changes.append(f"Orden: {display_order}")

    if changes:
        print(f"Grupo ID {group_id} actualizado:")
        for change in changes:
            print(f"  - {change}")
    else:
        print(f"No se detectaron cambios para grupo ID {group_id}.")

    return group


def delete_modifier_group(session, group_id: int):
    """Eliminar un grupo de modificadores."""
    group = session.get(ModifierGroup, group_id)
    if not group:
        print(f"Error: Grupo con ID {group_id} no encontrado.")
        return False

    group_name = group.name
    session.delete(group)
    print(f"Grupo '{group_name}' (ID {group_id}) eliminado exitosamente.")
    return True


def main():
    parser = argparse.ArgumentParser(description="Gestionar grupos de modificadores")
    parser.add_argument(
        "--action",
        choices=["list", "add", "update", "delete"],
        required=True,
        help="Acción a realizar",
    )
    parser.add_argument("--id", type=int, help="ID del grupo (para update/delete)")
    parser.add_argument("--name", help="Nombre del grupo")
    parser.add_argument("--description", help="Descripción del grupo")
    parser.add_argument("--min", type=int, help="Mínima selección")
    parser.add_argument("--max", type=int, help="Máxima selección")
    parser.add_argument("--required", type=bool, help="Es obligatorio")
    parser.add_argument("--order", type=int, help="Orden de visualización")

    args = parser.parse_args()

    init_database()

    with get_session() as session:
        if args.action == "list":
            list_modifier_groups(session)
        elif args.action == "add":
            if not args.name:
                print("Error: --name es requerido para agregar.")
                sys.exit(1)
            add_modifier_group(
                session,
                name=args.name,
                description=args.description,
                min_selection=args.min or 0,
                max_selection=args.max or 1,
                is_required=args.required if args.required is not None else False,
                display_order=args.order,
            )
            session.commit()
        elif args.action == "update":
            if not args.id:
                print("Error: --id es requerido para actualizar.")
                sys.exit(1)
            update_modifier_group(
                session,
                group_id=args.id,
                name=args.name,
                description=args.description,
                min_selection=args.min,
                max_selection=args.max,
                is_required=args.required,
                display_order=args.order,
            )
            session.commit()
        elif args.action == "delete":
            if not args.id:
                print("Error: --id es requerido para eliminar.")
                sys.exit(1)
            delete_modifier_group(session, args.id)
            session.commit()


if __name__ == "__main__":
    main()
