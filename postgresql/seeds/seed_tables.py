#!/usr/bin/env python3
"""
Script CRUD para Mesas (Tables).

Funciones:
- Agregar nuevas mesas
- Modificar mesas existentes
- Eliminar mesas
- Listar mesas

Uso:
    python seeds/seed_tables.py --action add --number "1" --area "Principal" --capacity 4
    python seeds/seed_tables.py --action list
    python seeds/seed_tables.py --action update --id 1 --capacity 6
    python seeds/seed_tables.py --action delete --id 1
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
from shared.models import Area, Base, Table
from shared.table_utils import build_table_code, derive_area_code


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


def list_tables(session, area_name=None, status=None):
    """Listar todas las mesas."""
    query = select(Table)
    if area_name:
        area = session.execute(
            select(Area).where(Area.name == area_name)
        ).scalar_one_or_none()
        if area:
            query = query.where(Table.area_id == area.id)
        else:
            print(f"Área '{area_name}' no encontrada.")
            return

    if status:
        query = query.where(Table.status == status)

    tables = session.execute(query).scalars().all()

    print(f"\n{'='*80}")
    print(f"MESAS ({len(tables)} total)")
    print(f"{'='*80}")

    for table in tables:
        area = session.get(Area, table.area_id)
        print(f"\nID: {table.id}")
        print(f"  Número: {table.table_number}")
        print(f"  Área: {area.name if area else 'N/A'}")
        print(f"  Capacidad: {table.capacity}")
        print(f"  Estado: {table.status}")
        print(f"  QR Code: {table.qr_code[:20]}..." if table.qr_code else "  QR Code: N/A")
        print(f"  Código: {table.table_code or 'N/A'}")

    return tables


def add_table(
    session,
    table_number: str,
    area_name: str,
    capacity: int = 4,
    status: str = "available",
):
    """Agregar una nueva mesa."""
    area = session.execute(
        select(Area).where(Area.name == area_name)
    ).scalar_one_or_none()

    if not area:
        print(f"Error: Área '{area_name}' no encontrada.")
        print("Áreas disponibles:")
        areas = session.execute(select(Area)).scalars().all()
        for a in areas:
            print(f"  - {a.name}")
        return None

    existing = session.execute(
        select(Table).where(
            Table.table_number == table_number,
            Table.area_id == area.id
        )
   _none()

    if ).scalar_one_or existing:
        print(f"Mesa '{table_number}' ya existe en área '{area_name}'.")
        print(f"  ID: {existing.id}")
        return existing

    area_prefix = area.prefix if area.prefix else derive_area_code(area.name)
    table_code = build_table_code(area_prefix, table_number)

    import hashlib
    import time
    unique_string = f"{area.name}-{table_number}-{int(time.time())}"
    qr_code = hashlib.sha256(unique_string.encode()).hexdigest()[:32]

    table = Table(
        table_number=table_number,
        area_id=area.id,
        capacity=capacity,
        status=status,
        table_code=table_code,
        qr_code=qr_code,
        is_active=True,
    )
    session.add(table)
    session.flush()
    print(f"Mesa '{table_number}' agregada exitosamente.")
    print(f"  ID: {table.id}")
    print(f"  Área: {area_name}")
    print(f"  Capacidad: {capacity}")
    print(f"  Código: {table_code}")
    return table


def update_table(
    session,
    table_id: int,
    table_number: str = None,
    capacity: int = None,
    status: str = None,
    is_active: bool = None,
):
    """Modificar una mesa existente."""
    table = session.get(Table, table_id)
    if not table:
        print(f"Error: Mesa con ID {table_id} no encontrada.")
        return None

    changes = []
    if table_number is not None and table_number != table.table_number:
        table.table_number = table_number
        changes.append(f"Número: {table_number}")

    if capacity is not None and capacity != table.capacity:
        table.capacity = capacity
        changes.append(f"Capacidad: {capacity}")

    if status is not None and status != table.status:
        table.status = status
        changes.append(f"Estado: {status}")

    if is_active is not None and is_active != table.is_active:
        table.is_active = is_active
        changes.append(f"Activa: {is_active}")

    if changes:
        print(f"Mesa ID {table_id} actualizada:")
        for change in changes:
            print(f"  - {change}")
    else:
        print(f"No se detectaron cambios para mesa ID {table_id}.")

    return table


def delete_table(session, table_id: int):
    """Eliminar (desactivar) una mesa."""
    table = session.get(Table, table_id)
    if not table:
        print(f"Error: Mesa con ID {table_id} no encontrada.")
        return False

    table_number = table.table_number
    table.is_active = False
    print(f"Mesa '{table_number}' (ID {table_id}) desactivada exitosamente.")
    return True


def generate_qr_codes(session, area_name=None):
    """Generar códigos QR para mesas sin código."""
    query = select(Table).where(Table.qr_code.is_(None))
    if area_name:
        area = session.execute(
            select(Area).where(Area.name == area_name)
        ).scalar_one_or_none()
        if area:
            query = query.where(Table.area_id == area.id)

    tables = session.execute(query).scalars().all()

    import hashlib
    import time

    count = 0
    for table in tables:
        area = session.get(Area, table.area_id)
        unique_string = f"{area.name if area else 'default'}-{table.table_number}-{int(time.time())}"
        table.qr_code = hashlib.sha256(unique_string.encode()).hexdigest()[:32]
        count += 1

    print(f"Códigos QR generados para {count} mesas.")
    return count


def main():
    parser = argparse.ArgumentParser(description="Gestionar mesas")
    parser.add_argument(
        "--action",
        choices=["list", "add", "update", "delete", "generate-qr"],
        required=True,
        help="Acción a realizar",
    )
    parser.add_argument("--id", type=int, help="ID de la mesa (para update/delete)")
    parser.add_argument("--number", help="Número de mesa")
    parser.add_argument("--area", help="Nombre del área")
    parser.add_argument("--capacity", type=int, help="Capacidad de personas")
    parser.add_argument("--status", help="Estado de la mesa")
    parser.add_argument("--inactive", action="store_true", help="Mesa inactiva")
    parser.add_argument("--area-filter", help="Filtrar por área")
    parser.add_argument("--status-filter", help="Filtrar por estado")

    args = parser.parse_args()

    init_database()

    with get_session() as session:
        if args.action == "list":
            list_tables(session, args.area_filter, args.status_filter)
        elif args.action == "add":
            if not args.number or not args.area:
                print("Error: --number y --area son requeridos para agregar.")
                sys.exit(1)
            add_table(
                session,
                table_number=args.number,
                area_name=args.area,
                capacity=args.capacity or 4,
                status=args.status or "available",
            )
            session.commit()
        elif args.action == "update":
            if not args.id:
                print("Error: --id es requerido para actualizar.")
                sys.exit(1)
            update_table(
                session,
                table_id=args.id,
                table_number=args.number,
                capacity=args.capacity,
                status=args.status,
                is_active=not args.inactive if args.inactive else None,
            )
            session.commit()
        elif args.action == "delete":
            if not args.id:
                print("Error: --id es requerido para eliminar.")
                sys.exit(1)
            delete_table(session, args.id)
            session.commit()
        elif args.action == "generate-qr":
            generate_qr_codes(session, args.area_filter)
            session.commit()


if __name__ == "__main__":
    main()
