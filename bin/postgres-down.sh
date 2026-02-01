#!/bin/bash
# Stop PostgreSQL local container for Pronto

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"

echo "🛑 Deteniendo PostgreSQL local..."
docker compose -f "${COMPOSE_FILE}" stop postgres

echo "✅ PostgreSQL detenido (datos preservados en volumen postgres_data)"
echo ""
echo "Para reiniciar:"
echo "  bash bin/postgres-up.sh"
echo ""
echo "Para eliminar completamente (incluyendo datos):"
echo "  bash bin/postgres-down.sh --remove-data"
