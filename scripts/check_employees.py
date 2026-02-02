#!/usr/bin/env python3
"""
Script para verificar qué empleados existen en la base de datos
"""

import os
import sys
from pathlib import Path

# Cargar variables de ambiente desde .env
PROJECT_ROOT = Path(__file__).parent.parent
ENV_FILE = PROJECT_ROOT / ".env"


def load_env_file(env_path):
    """Cargar variables de ambiente desde un archivo .env"""
    if not env_path.exists():
        return

    with env_path.open() as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip()
                if key not in os.environ:
                    os.environ[key] = value


# Cargar archivos de configuración
load_env_file(ENV_FILE)

# Agregar el directorio build al path
sys.path.insert(0, str(PROJECT_ROOT / "build"))

from sqlalchemy import select  # noqa: E402

from pronto_shared.config import load_config  # noqa: E402
from pronto_shared.db import get_session, init_engine  # noqa: E402
from pronto_shared.models import Employee  # noqa: E402


def main():
    """Función principal"""
    print("\n🔍 VERIFICANDO EMPLEADOS EN BASE DE DATOS")
    print("=" * 80 + "\n")

    # Inicializar engine
    config = load_config("check-employees")
    init_engine(config)

    with get_session() as session:
        employees = (
            session.execute(select(Employee).order_by(Employee.id)).scalars().all()
        )

        if not employees:
            print("❌ NO HAY EMPLEADOS EN LA BASE DE DATOS")
            print("\nEjecuta este comando para crear empleados:")
            print("   docker exec -it pronto-api python scripts/seed_test_data.py")
            return

        print(f"✅ Encontrados {len(employees)} empleados:\n")
        print(f"{'ID':<5} {'Nombre':<25} {'Email':<40} {'Rol':<15} {'Activo':<8}")
        print("-" * 100)

        for emp in employees:
            active_str = "✓ Sí" if emp.is_active else "✗ No"
            print(
                f"{emp.id:<5} {emp.name:<25} {emp.email:<40} {emp.role:<15} {active_str:<8}"
            )

        print("\n" + "=" * 80)
        print("💡 Password por defecto para todos: ChangeMe!123")
        print("=" * 80 + "\n")


if __name__ == "__main__":
    main()
