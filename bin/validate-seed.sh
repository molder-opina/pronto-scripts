#!/bin/bash
# Validate and seed database
# Verifica que la base de datos tenga todos los datos necesarios y los crea si faltan

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SEED_SCRIPT="${SCRIPT_DIR}/python/validate_and_seed.py"

detect_container() {
  if docker ps --format '{{.Names}}' | rg -x 'pronto-employees-1' >/dev/null; then
    echo "pronto-employees-1"
    return 0
  fi
  if docker ps --format '{{.Names}}' | rg -x 'pronto-employee' >/dev/null; then
    echo "pronto-employee"
    return 0
  fi
  return 1
}

if [[ ! -f "${SEED_SCRIPT}" ]]; then
  echo "❌ Script de seed no encontrado: ${SEED_SCRIPT}" >&2
  exit 1
fi

if ! CONTAINER_NAME="$(detect_container)"; then
  echo "❌ No se encontró contenedor de employees activo (esperado: pronto-employees-1 o pronto-employee)." >&2
  exit 1
fi

echo "🔍 Validando y creando seed data en la base de datos..."
echo "📦 Contenedor detectado: ${CONTAINER_NAME}"
echo ""

# Execute inside the employee container
if ! docker exec "${CONTAINER_NAME}" python3 -c "
import sys
sys.path.insert(0, '/opt/pronto')

from pronto_shared.db import init_engine, get_session
from pronto_shared.config import load_config
from pronto_shared.models import (
    Employee, MenuCategory, MenuItem, Area, Table,
    SystemSetting, DayPeriod
)
from pronto_shared.security import hash_credentials, hash_identifier

# Initialize database
config = load_config('validate_seed')
init_engine(config)

print('=' * 80)
print('  VALIDACIÓN DE BASE DE DATOS')
print('=' * 80)

with get_session() as db:
    employees_count = db.query(Employee).count()
    categories_count = db.query(MenuCategory).count()
    products_count = db.query(MenuItem).count()
    areas_count = db.query(Area).count()
    tables_count = db.query(Table).count()
    config_count = db.query(SystemSetting).count()
    periods_count = db.query(DayPeriod).count()

    print(f'✅ Empleados: {employees_count}')
    print(f'✅ Categorías: {categories_count}')
    print(f'✅ Productos: {products_count}')
    print(f'✅ Áreas: {areas_count}')
    print(f'✅ Mesas: {tables_count}')
    print(f'✅ Configuración (SystemSetting): {config_count}')
    print(f'✅ Períodos del día: {periods_count}')

    needs_seed = (
        employees_count == 0 or
        categories_count == 0 or
        products_count == 0 or
        areas_count == 0 or
        tables_count == 0 or
        config_count < 9 or
        periods_count == 0
    )

    if needs_seed:
        print('')
        print('⚠️  FALTAN DATOS - Ejecutando seed...')
        print('')
    else:
        print('')
        print('✅ Todos los datos necesarios están presentes')
        print('=' * 80)
        sys.exit(0)

# If we need to seed, run the full script
"; then
  echo "❌ Falló la validación preliminar de seed." >&2
  exit 1
fi

if ! docker cp "${SEED_SCRIPT}" "${CONTAINER_NAME}:/tmp/validate_and_seed.py"; then
  echo "❌ No se pudo copiar validate_and_seed.py al contenedor." >&2
  exit 1
fi

if ! docker exec "${CONTAINER_NAME}" python3 /tmp/validate_and_seed.py; then
  echo "❌ Falló la ejecución de validate_and_seed.py." >&2
  exit 1
fi

echo ""
echo "✅ Validación completada"
