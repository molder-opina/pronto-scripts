#!/usr/bin/env bash
# bin/mac/logs.sh — Muestra logs de servicios en macOS con Docker Desktop
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENV_FILE="${PROJECT_ROOT}/.env"

# Load environment variables
set -a
# shellcheck source=../../.env
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-pronto}"
COMPOSE_CMD=(docker compose -f "${PROJECT_ROOT}/docker-compose.yml" -p "${COMPOSE_PROJECT_NAME}" --env-file "${ENV_FILE}")

if [[ $# -eq 0 ]]; then
  echo "Uso: $(basename "$0") <servicio> [-f]"
  echo ""
  echo "Servicios disponibles:"
  echo "  client     - Aplicación de clientes"
  echo "  employee   - Aplicación de empleados"
  echo "  static     - Servidor de archivos estáticos"
  echo "  redis      - Servicio Redis"
  echo ""
  echo "Opciones:"
  echo "  -f         Seguir logs en tiempo real (follow)"
  echo ""
  echo "Ejemplo:"
  echo "  $(basename "$0") employee -f"
  echo "  $(basename "$0") client"
  exit 1
fi

SERVICE="$1"
FOLLOW_FLAG=""

if [[ $# -ge 2 ]] && [[ "$2" == "-f" ]]; then
  FOLLOW_FLAG="-f"
fi

echo "📝 Logs de ${SERVICE}:"
echo ""
"${COMPOSE_CMD[@]}" logs ${FOLLOW_FLAG} "${SERVICE}"
