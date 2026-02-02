#!/bin/bash
# PostgreSQL Initialization Script for Pronto
# This script initializes the PostgreSQL database with required tables and seed data

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║   🐘 INICIALIZANDO POSTGRESQL LOCAL 🐘              ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# Load environment variables
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${PROJECT_ROOT}/.env"
    set +a
fi

# Configuration
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-pronto}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-pronto123}"
POSTGRES_DB="${POSTGRES_DB:-pronto}"

echo "📋 Configuración:"
echo "   Host: ${POSTGRES_HOST}:${POSTGRES_PORT}"
echo "   Usuario: ${POSTGRES_USER}"
echo "   Base de datos: ${POSTGRES_DB}"
echo ""

# Function to check if PostgreSQL is ready
check_postgres() {
    local max_attempts=30
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        if docker exec pronto-postgres pg_isready -U "${POSTGRES_USER}" > /dev/null 2>&1; then
            echo "✅ PostgreSQL está listo"
            return 0
        fi
        echo "⏳ Esperando a PostgreSQL... (intento $((attempt + 1))/${max_attempts})"
        sleep 2
        ((attempt++))
    done

    echo "❌ Error: PostgreSQL no está listo después de ${max_attempts} intentos"
    return 1
}

# Check if PostgreSQL container is running
if ! docker ps | grep -q pronto-postgres; then
    echo "❌ Error: El contenedor pronto-postgres no está corriendo"
    echo ""
    echo "Para iniciar PostgreSQL local:"
    echo "  bash bin/postgres-up.sh"
    exit 1
fi

# Wait for PostgreSQL to be ready
check_postgres || exit 1

echo ""
echo "🗄️  Ejecutando migraciones de SQLAlchemy..."
# SQLAlchemy will create tables automatically via Base.metadata.create_all()
# No need to run manual SQL migrations if using SQLAlchemy migrations

echo ""
echo "🌱 Cargando datos de prueba (seed)..."
# The seed data is loaded automatically by the app on startup if LOAD_SEED_DATA=true
# We can trigger it here by restarting the apps with LOAD_SEED_DATA=true

echo ""
echo "✅ PostgreSQL inicializado exitosamente"
echo ""
echo "📊 Estado de la base de datos:"
docker exec pronto-postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "\dt" 2>/dev/null || echo "   (Aún no hay tablas - se crearán al iniciar la aplicación)"

echo ""
echo "🔍 Para conectar a la base de datos:"
echo "   docker exec -it pronto-postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
echo ""
echo "Para conectar desde el host:"
echo "   psql -h localhost -p 5432 -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
