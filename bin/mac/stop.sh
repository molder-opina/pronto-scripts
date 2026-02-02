#!/usr/bin/env bash
# bin/mac/stop.sh — Detiene servicios localmente en macOS con Docker Desktop
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENV_FILE="${PROJECT_ROOT}/.env"
source "${SCRIPT_DIR}/_check_required_files.sh" 2>/dev/null || true

SERVICES=()

show_usage() {
    cat <<EOF
Uso: $(basename "$0") [servicios]

Servicios disponibles:
  client
  employee
  api
  static
  all (por defecto - incluye todos)

Ejemplos:
  $(basename "$0")
  $(basename "$0") client employee
  $(basename "$0") static
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        all)
            SERVICES=()
            shift
            ;;
        client|employee|static|api)
            SERVICES+=("$1")
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "❌ Opción o servicio desconocido: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Load environment variables
set -a
# shellcheck source=../../.env
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-pronto}"
COMPOSE_CMD=(docker compose -f "${PROJECT_ROOT}/docker-compose.yml" -p "${COMPOSE_PROJECT_NAME}" --env-file "${ENV_FILE}")

if [[ ${#SERVICES[@]} -eq 0 ]]; then
    SERVICES=(client employee api static)
fi

echo "🛑 Deteniendo servicios: ${SERVICES[*]}"
"${COMPOSE_CMD[@]}" stop -t 10 "${SERVICES[@]}" 2>/dev/null || true
"${COMPOSE_CMD[@]}" rm -f -s "${SERVICES[@]}" 2>/dev/null || true

echo "✅ Servicios detenidos."
