#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-pronto}"

echo "====================================================="
echo "🔄 RESTABLECIENDO BASE DE DATOS Y APLICANDO SEEDS 🔄"
echo "====================================================="

echo "1. Deteniendo contenedores y eliminando volúmenes de base de datos..."
cd "$PROJECT_ROOT"
docker compose --project-name "${COMPOSE_PROJECT_NAME}" down -v
docker volume rm "${COMPOSE_PROJECT_NAME}_postgres_data" pronto_postgres_data 2>/dev/null || true

echo "2. Iniciando base de datos y memoria caché de Redis primero..."
docker compose --project-name "${COMPOSE_PROJECT_NAME}" up -d postgres redis
echo "⏳ Esperando a que PostgreSQL inicie..."
until docker exec "${COMPOSE_PROJECT_NAME}-postgres-1" pg_isready -U pronto > /dev/null 2>&1 || [ $? -eq 1 ]; do
  sleep 2
done
# Esperar un par de segundos adicionales para que acepte conexiones
sleep 3


echo "3. Ejecutando scripts de inicialización de la base de datos (pronto-init y pronto-migrate)..."
export DATABASE_URL="postgresql://pronto:pronto123@localhost:5432/pronto"
"$PROJECT_ROOT/pronto-scripts/bin/pronto-init" --apply
"$PROJECT_ROOT/pronto-scripts/bin/pronto-migrate" --apply

echo "🛑 Deteniendo base de datos para evitar colisión de puertos en macOS..."
docker compose --project-name "${COMPOSE_PROJECT_NAME}" down
sleep 3

echo "4. Iniciando servicios restantes con la bandera --seed..."

"$PROJECT_ROOT/pronto-scripts/bin/up.sh" --seed || true

echo "⏳ Esperando a que el contenedor de empleados esté listo (10s)..."
sleep 10

echo "5. Ejecutando seed modular Python..."
docker exec "${COMPOSE_PROJECT_NAME}-employees-1" python3 -c "
import sys
sys.path.insert(0, '/opt/pronto/pronto_employees')
from pronto_shared.config import load_config
from pronto_shared.db import get_session, init_engine
from pronto_shared.services.seed_impl import ensure_seed_data
config = load_config('employee')
init_engine(config)
with get_session() as session:
    ensure_seed_data(session)
"

echo "====================================================="
echo "✅ Sistema restablecido con seeds mínimos exitosamente."
echo "====================================================="
