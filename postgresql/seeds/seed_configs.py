#!/usr/bin/env python3
"""
Script CRUD para Configuraciones del Negocio (BusinessConfig).

Funciones:
- Agregar nuevas configuraciones
- Modificar configuraciones existentes
- Eliminar configuraciones
- Listar configuraciones

Uso:
    python seeds/seed_configs.py --action list
    python seeds/seed_configs.py --action update --key "tax_rate" --value 16.0
    python seeds/seed_configs.py --action add --key "nueva_config" --display-name "Nueva Configuración" --value "test" --type "string"
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
from shared.models import Base, BusinessConfig


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


def list_configs(session, category=None):
    """Listar todas las configuraciones."""
    query = select(BusinessConfig)
    if category:
        query = query.where(BusinessConfig.category == category)

    configs = session.execute(query).scalars().all()

    print(f"\n{'=' * 80}")
    print(f"CONFIGURACIONES ({len(configs)} total)")
    print(f"{'=' * 80}")

    for config in configs:
        print(f"\nID: {config.id}")
        print(f"  Key: {config.config_key}")
        print(f"  Display Name: {config.display_name or 'N/A'}")
        print(f"  Valor: {config.config_value}")
        print(f"  Tipo: {config.value_type}")
        print(f"  Categoría: {config.category or 'N/A'}")
        print(f"  Descripción: {config.description or 'N/A'}")

    return configs


def get_config(session, config_key: str):
    """Obtener una configuración por su key."""
    return session.execute(
        select(BusinessConfig).where(BusinessConfig.config_key == config_key)
    ).scalar_one_or_none()


def add_config(
    session,
    config_key: str,
    config_value: str,
    value_type: str = "string",
    display_name: str = None,
    category: str = "general",
    description: str = None,
    min_value=None,
    max_value=None,
    unit=None,
):
    """Agregar una nueva configuración."""
    existing = get_config(session, config_key)
    if existing:
        print(f"Configuración '{config_key}' ya existe.")
        print(f"  ID: {existing.id}")
        print(f"  Valor actual: {existing.config_value}")
        return existing

    config = BusinessConfig(
        config_key=config_key,
        config_value=str(config_value),
        value_type=value_type,
        display_name=display_name,
        category=category,
        description=description,
        min_value=min_value,
        max_value=max_value,
        unit=unit,
    )
    session.add(config)
    session.flush()
    print(f"Configuración '{config_key}' agregada exitosamente.")
    print(f"  ID: {config.id}")
    print(f"  Valor: {config_value}")
    print(f"  Tipo: {value_type}")
    return config


def update_config(
    session,
    config_key: str = None,
    config_id: int = None,
    config_value: str = None,
    display_name: str = None,
    description: str = None,
    min_value=None,
    max_value=None,
    unit=None,
):
    """Modificar una configuración existente."""
    if config_id:
        config = session.get(BusinessConfig, config_id)
    elif config_key:
        config = get_config(session, config_key)
    else:
        print("Error: Debes especificar --key o --id.")
        return None

    if not config:
        print(f"Error: Configuración no encontrada.")
        return None

    changes = []
    if config_value is not None and config_value != config.config_value:
        config.config_value = config_value
        changes.append(f"Valor: {config_value}")

    if display_name is not None and display_name != config.display_name:
        config.display_name = display_name
        changes.append(f"Display Name: {display_name}")

    if description is not None and description != config.description:
        config.description = description
        changes.append(f"Descripción: {description}")

    if changes:
        print(f"Configuración '{config.config_key}' actualizada:")
        for change in changes:
            print(f"  - {change}")
    else:
        print(f"No se detectaron cambios para configuración '{config.config_key}'.")

    return config


def delete_config(session, config_id: int):
    """Eliminar una configuración."""
    config = session.get(BusinessConfig, config_id)
    if not config:
        print(f"Error: Configuración con ID {config_id} no encontrada.")
        return False

    config_key = config.config_key
    session.delete(config)
    print(f"Configuración '{config_key}' (ID {config_id}) eliminada.")
    return True


def reset_to_defaults(session):
    """Restaurar configuraciones por defecto."""
    default_configs = [
        (
            "restaurant_name",
            "Pronto Café",
            "string",
            "Nombre del Restaurante",
            "general",
            "Nombre visible del negocio",
        ),
        (
            "currency_symbol",
            "$",
            "string",
            "Símbolo de moneda",
            "general",
            "Símbolo para precios",
        ),
        (
            "tax_rate",
            "16.0",
            "float",
            "Tasa de Impuesto (%)",
            "payments",
            None,
            "0.0",
            "100.0",
            "%",
        ),
        (
            "enable_tips",
            "true",
            "bool",
            "Habilitar Propinas",
            "payments",
            "Permitir propinas en el pago",
        ),
        ("items_per_page", "10", "select", "Ítems por página", "general", None),
        (
            "enable_email_notifications",
            "true",
            "bool",
            "Notificaciones Email",
            "notifications",
            None,
        ),
        (
            "kitchen_display_mode",
            "standard",
            "select",
            "Modo Pantalla Cocina",
            "kitchen",
            "Layout de la pantalla de cocina",
        ),
        (
            "session_timeout_minutes",
            "120",
            "int",
            "Timeout Sesión (min)",
            "sessions",
            None,
            "5",
            None,
            "min",
        ),
        (
            "auto_accept_orders",
            "false",
            "bool",
            "Aceptar órdenes automáticamente",
            "orders",
            "Pasar órdenes directo a cocina",
        ),
        (
            "max_guests_per_table",
            "10",
            "int",
            "Máx. comensales por mesa",
            "sessions",
            None,
            "1",
            "50",
            None,
        ),
    ]

    for key, value, vtype, display, category, desc, minv, maxv, unit in default_configs:
        add_config(
            session,
            config_key=key,
            config_value=value,
            value_type=vtype,
            display_name=display,
            category=category,
            description=desc,
            min_value=minv,
            max_value=maxv,
            unit=unit,
        )

    print(f"{len(default_configs)} configuraciones restauradas.")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Gestionar configuraciones del negocio"
    )
    parser.add_argument(
        "--action",
        choices=["list", "add", "update", "delete", "reset"],
        required=True,
        help="Acción a realizar",
    )
    parser.add_argument(
        "--id", type=int, help="ID de la configuración (para update/delete)"
    )
    parser.add_argument("--key", help="Key de la configuración")
    parser.add_argument("--value", help="Valor de la configuración")
    parser.add_argument("--display-name", help="Nombre para mostrar")
    parser.add_argument(
        "--type", help="Tipo de valor (string, int, float, bool, select)"
    )
    parser.add_argument("--category", help="Categoría")
    parser.add_argument("--description", help="Descripción")
    parser.add_argument("--category-filter", help="Filtrar por categoría")
    parser.add_argument("--min", help="Valor mínimo")
    parser.add_argument("--max", help="Valor máximo")
    parser.add_argument("--unit", help="Unidad")

    args = parser.parse_args()

    init_database()

    with get_session() as session:
        if args.action == "list":
            list_configs(session, args.category_filter)
        elif args.action == "reset":
            reset_to_defaults(session)
            session.commit()
        elif args.action == "add":
            if not args.key or not args.value:
                print("Error: --key y --value son requeridos para agregar.")
                sys.exit(1)
            add_config(
                session,
                config_key=args.key,
                config_value=args.value,
                value_type=args.type or "string",
                display_name=args.display_name,
                category=args.category or "general",
                description=args.description,
                min_value=args.min,
                max_value=args.max,
                unit=args.unit,
            )
            session.commit()
        elif args.action == "update":
            if not args.key and not args.id:
                print("Error: --key o --id es requerido para actualizar.")
                sys.exit(1)
            update_config(
                session,
                config_key=args.key,
                config_id=args.id,
                config_value=args.value,
                display_name=args.display_name,
                description=args.description,
                min_value=args.min,
                max_value=args.max,
                unit=args.unit,
            )
            session.commit()
        elif args.action == "delete":
            if not args.id:
                print("Error: --id es requerido para eliminar.")
                sys.exit(1)
            delete_config(session, args.id)
            session.commit()


if __name__ == "__main__":
    main()
