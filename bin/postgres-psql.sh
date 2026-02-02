#!/bin/bash
# Connect to PostgreSQL local database

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load environment variables
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${PROJECT_ROOT}/.env"
    set +a
fi

POSTGRES_USER="${POSTGRES_USER:-pronto}"
POSTGRES_DB="${POSTGRES_DB:-pronto}"

# Check if container is running
if ! docker ps --format "{{.Names}}" | grep -q pronto-postgres; then
    echo "❌ Error: El contenedor pronto-postgres no está corriendo"
    echo ""
    echo "Para iniciar:"
    echo "  bash bin/postgres-up.sh"
    exit 1
fi

echo "🔗 Conectando a PostgreSQL..."
echo "   Usuario: ${POSTGRES_USER}"
echo "   Base de datos: ${POSTGRES_DB}"
echo ""
echo "Comandos útiles:"
echo "   \l           - Listar bases de datos"
echo "   \d           - Listar tablas"
echo "   \d nombre_tabla - Describir tabla"
echo "   \q           - Salir"
echo ""
echo "---------------------------------------------------"

# Connect to PostgreSQL
docker exec -it pronto-postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}"
