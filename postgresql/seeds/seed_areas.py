#!/usr/bin/env python3
"""
Script CRUD para Áreas (Areas).

Funciones:
- Agregar nuevas áreas
- Modificar áreas existentes
- Eliminar áreas
- Listar áreas

Uso:
    python seeds/seed_areas.py --action add --name "Terraza" --prefix "T" --color "#ff6b35"
    python seeds/seed_areas.py --action list
    python seeds/seed_areas.py --action update --id 1 --color "#00ff00"
    python seeds/seed_areas.py --action delete --id 1
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
from shared.models import Area, Base


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


def list_areas(session):
    """Listar todas las áreas."""
    areas = session.execute(select(Area)).scalars().all()

    print(f"\n{'=' * 80}")
    print(f"ÁREAS ({len(areas)} total)")
    print(f"{'=' * 80}")

    for area in areas:
        print(f"\nID: {area.id}")
        print(f"  Nombre: {area.name}")
        print(f"  Descripción: {area.description or 'N/A'}")
        print(f"  Prefijo: {area.prefix or 'N/A'}")
        print(f"  Color: {area.color}")
        print(f"  Activa: {'Sí' if area.is_active else 'No'}")

    return areas


def add_area(
    session,
    name: str,
    description: str = None,
    prefix: str = None,
    color: str = "#ff6b35",
    is_active: bool = True,
):
    """Agregar una nueva área."""
    existing = session.execute(
        select(Area).where(Area.name == name)
    ).scalar_one_or_none()

    if existing:
        print(f"Área '{name}' ya existe.")
        print(f"  ID: {existing.id}")
        return existing

    if prefix is None:
        prefix = name[:2].upper()

    area = Area(
        name=name,
        description=description,
        prefix=prefix,
        color=color,
        is_active=is_active,
    )
    session.add(area)
    session.flush()
    print(f"Área '{name}' agregada exitosamente.")
    print(f"  ID: {area.id}")
    print(f"  Prefijo: {prefix}")
    print(f"  Color: {color}")
    return area


def update_area(
    session,
    area_id: int,
    name: str = None,
    description: str = None,
    prefix: str = None,
    color: str = None,
    is_active: bool = None,
):
    """Modificar un área existente."""
    area = session.get(Area, area_id)
    if not area:
        print(f"Error: Área con ID {area_id} no encontrada.")
        return None

    changes = []
    if name is not None and name != area.name:
        area.name = name
        changes.append(f"Nombre: {name}")

    if description is not None and description != area.description:
        area.description = description
        changes.append(f"Descripción: {description}")

    if prefix is not None and prefix != area.prefix:
        area.prefix = prefix
        changes.append(f"Prefijo: {prefix}")

    if color is not None and color != area.color:
        area.color = color
        changes.append(f"Color: {color}")

    if is_active is not None and is_active != area.is_active:
        area.is_active = is_active
        changes.append(f"Activa: {is_active}")

    if changes:
        print(f"Área ID {area_id} actualizada:")
        for change in changes:
            print(f"  - {change}")
    else:
        print(f"No se detectaron cambios para área ID {area_id}.")

    return area


def delete_area(session, area_id: int):
    """Eliminar (desactivar) un área."""
    area = session.get(Area, area_id)
    if not area:
        print(f"Error: Área con ID {area_id} no encontrada.")
        return False

    area_name = area.name
    area.is_active = False
    print(f"Área '{area_name}' (ID {area_id}) desactivada exitosamente.")
    return True


def main():
    parser = argparse.ArgumentParser(description="Gestionar áreas")
    parser.add_argument(
        "--action",
        choices=["list", "add", "update", "delete"],
        required=True,
        help="Acción a realizar",
    )
    parser.add_argument("--id", type=int, help="ID del área (para update/delete)")
    parser.add_argument("--name", help="Nombre del área")
    parser.add_argument("--description", help="Descripción del área")
    parser.add_argument("--prefix", help="Prefijo para códigos de mesa")
    parser.add_argument("--color", help="Color hexadecimal")
    parser.add_argument("--inactive", action="store_true", help="Área inactiva")

    args = parser.parse_args()

    init_database()

    with get_session() as session:
        if args.action == "list":
            list_areas(session)
        elif args.action == "add":
            if not args.name:
                print("Error: --name es requerido para agregar.")
                sys.exit(1)
            add_area(
                session,
                name=args.name,
                description=args.description,
                prefix=args.prefix,
                color=args.color or "#ff6b35",
                is_active=not args.inactive,
            )
            session.commit()
        elif args.action == "update":
            if not args.id:
                print("Error: --id es requerido para actualizar.")
                sys.exit(1)
            update_area(
                session,
                area_id=args.id,
                name=args.name,
                description=args.description,
                prefix=args.prefix,
                color=args.color,
                is_active=not args.inactive if args.inactive else None,
            )
            session.commit()
        elif args.action == "delete":
            if not args.id:
                print("Error: --id es requerido para eliminar.")
                sys.exit(1)
            delete_area(session, args.id)
            session.commit()


if __name__ == "__main__":
    main()
