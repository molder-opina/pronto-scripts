#!/bin/bash
# Validate and seed database
# Verifica que la base de datos tenga todos los datos necesarios y los crea si faltan

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔍 Validando y creando seed data en la base de datos..."
echo ""

# Execute inside the employee container
docker exec pronto-employee python3 -c "
import sys
sys.path.insert(0, '/opt/pronto')

from shared.db import init_engine, get_session
from shared.config import load_config
from shared.models import (
    Employee, MenuCategory, MenuItem, Area, Table,
    BusinessConfig, DayPeriod
)
from shared.security import hash_credentials, hash_identifier

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
    config_count = db.query(BusinessConfig).count()
    periods_count = db.query(DayPeriod).count()

    print(f'✅ Empleados: {employees_count}')
    print(f'✅ Categorías: {categories_count}')
    print(f'✅ Productos: {products_count}')
    print(f'✅ Áreas: {areas_count}')
    print(f'✅ Mesas: {tables_count}')
    print(f'✅ Configuración: {config_count}')
    print(f'✅ Períodos del día: {periods_count}')

    needs_seed = (
        employees_count == 0 or
        categories_count == 0 or
        products_count == 0 or
        areas_count == 0 or
        tables_count == 0 or
        config_count == 0 or
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
" && docker cp bin/python/validate_and_seed.py pronto-employee:/tmp/validate_and_seed.py && docker exec pronto-employee python3 /tmp/validate_and_seed.py

echo ""
echo "✅ Validación completada"
