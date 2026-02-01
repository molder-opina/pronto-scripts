#!/bin/bash
# Start PostgreSQL local container for Pronto

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"

echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║   🐘 INICIANDO POSTGRESQL LOCAL 🐘                 ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# Load environment variables
if [[ -f "${PROJECT_ROOT}/config/general.env" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${PROJECT_ROOT}/config/general.env"
    set +a
fi

POSTGRES_HOST_PORT="${POSTGRES_HOST_PORT:-5432}"

echo "📋 Configuración:"
echo "   Puerto host: ${POSTGRES_HOST_PORT}"
echo "   Usuario: ${POSTGRES_USER:-pronto}"
echo "   Base de datos: ${POSTGRES_DB:-pronto}"
echo ""

# Check if port is already in use
if lsof -Pi :${POSTGRES_HOST_PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  El puerto ${POSTGRES_HOST_PORT} ya está en uso"
    echo ""
    echo "Puede que PostgreSQL ya esté corriendo. Para verificar:"
    echo "  docker ps | grep pronto-postgres"
    echo ""
    read -p "¿Desea continuar de todas formas? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Start PostgreSQL container
echo "🚀 Iniciando contenedor pronto-postgres..."
docker compose -f "${COMPOSE_FILE}" up -d postgres

# Wait for PostgreSQL to be ready
echo ""
echo "⏳ Esperando a que PostgreSQL esté listo..."
max_attempts=30
attempt=0

while [[ $attempt -lt $max_attempts ]]; do
    if docker exec pronto-postgres pg_isready -U "${POSTGRES_USER:-pronto}" > /dev/null 2>&1; then
        echo "✅ PostgreSQL está listo"
        break
    fi
    echo "   Esperando... (intento $((attempt + 1))/${max_attempts})"
    sleep 2
    ((attempt++))
done

if [[ $attempt -eq $max_attempts ]]; then
    echo "❌ Error: PostgreSQL no inició correctamente"
    echo ""
    echo "Ver logs con:"
    echo "  bash bin/postgres-logs.sh"
    exit 1
fi

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║   ✅ POSTGRESQL LOCAL INICIADO                   ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
echo "🔍 Comandos útiles:"
echo "   bash bin/postgres-logs.sh      - Ver logs"
echo "   bash bin/postgres-psql.sh      - Conectar a la base de datos"
echo "   bash bin/postgres-down.sh      - Detener"
echo "   bash bin/postgres-backup.sh    - Hacer backup"
echo ""
echo "📊 Para conectar desde otra aplicación:"
echo "   Host: localhost"
echo "   Port: ${POSTGRES_HOST_PORT}"
echo "   User: ${POSTGRES_USER:-pronto}"
echo "   Password: ${POSTGRES_PASSWORD:-pronto123}"
echo "   Database: ${POSTGRES_DB:-pronto}"
echo ""
