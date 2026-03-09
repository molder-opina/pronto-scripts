#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=bin/lib/docker-runtime.sh
source "${SCRIPT_DIR}/lib/docker-runtime.sh"
# shellcheck source=bin/lib/stack-helpers.sh
source "${SCRIPT_DIR}/lib/stack-helpers.sh"

ENV_FILE="${PROJECT_ROOT}/.env"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"

SERVICES=()

show_usage() {
  cat <<EOF
Uso: $(basename "$0") [servicios]

Servicios disponibles:
  client
  employee
  all (por defecto)

Ejemplos:
  $(basename "$0")
  $(basename "$0") client
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    all)
      SERVICES=()
      shift
      ;;
    client|employee)
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

if [[ ${#SERVICES[@]} -eq 0 ]]; then
  SERVICES=(client employee)
fi

detect_compose_command "${COMPOSE_FILE}"
if [[ " ${COMPOSE_CMD[*]} " != *" --env-file "* ]]; then
  COMPOSE_CMD+=(--env-file "${ENV_FILE}")
fi

CLIENT_PORT="${CLIENT_APP_HOST_PORT:-6080}"
EMPLOYEE_PORT="${EMPLOYEE_APP_HOST_PORT:-6081}"

echo "📊 Estado de servicios Pronto:"
echo ""
"${COMPOSE_CMD[@]}" ps "${SERVICES[@]}"

echo ""
echo "🌐 URLs disponibles:"
for service in "${SERVICES[@]}"; do
  case "$service" in
    employee) echo "   • App Empleados: http://localhost:${EMPLOYEE_PORT}" ;;
    client) echo "   • App Clientes:  http://localhost:${CLIENT_PORT}" ;;
  esac
done
