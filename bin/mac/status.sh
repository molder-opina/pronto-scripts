#!/usr/bin/env bash
# bin/mac/status.sh — Muestra el estado de servicios en macOS con Docker Desktop
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SERVICES=()
source "${SCRIPT_DIR}/_check_required_files.sh" 2>/dev/null || true

show_usage() {
  cat <<EOF
Uso: $(basename "$0") [servicios]

Servicios disponibles:
  client
  employee
  static
  all (por defecto - incluye client, employee, static)

Ejemplos:
  $(basename "$0")
  $(basename "$0") client
  $(basename "$0") client static
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    all)
      SERVICES=()
      shift
      ;;
    client|employee|static)
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

ENV_FILE="${PROJECT_ROOT}/.env"

# Load environment variables
set -a
# shellcheck source=../../.env
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-pronto}"
COMPOSE_CMD=(docker compose -f "${PROJECT_ROOT}/docker-compose.yml" -p "${COMPOSE_PROJECT_NAME}" --env-file "${ENV_FILE}")

CLIENT_PORT="${CLIENT_APP_HOST_PORT:-6080}"
EMPLOYEE_PORT="${EMPLOYEE_APP_HOST_PORT:-6081}"
STATIC_PORT="${STATIC_APP_HOST_PORT:-9088}"

if [[ ${#SERVICES[@]} -eq 0 ]]; then
  SERVICES=(client employee static)
fi

echo "📊 Estado de servicios Pronto:"
echo ""
"${COMPOSE_CMD[@]}" ps "${SERVICES[@]}"

echo ""
echo "🌐 URLs disponibles:"
for service in "${SERVICES[@]}"; do
  case "$service" in
    employee) echo "   • App Empleados: http://localhost:${EMPLOYEE_PORT}" ;;
    client) echo "   • App Clientes:  http://localhost:${CLIENT_PORT}" ;;
    static) echo "   • Servidor Estático: http://localhost:${STATIC_PORT}" ;;
  esac
done
