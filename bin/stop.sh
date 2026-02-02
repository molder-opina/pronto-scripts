#!/usr/bin/env bash
# bin/stop.sh — Detiene servicios localmente en Linux con Docker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"
SECRETS_FILE="${PROJECT_ROOT}/.env"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"
SERVICES=()

# shellcheck source=bin/lib/docker_runtime.sh
source "${SCRIPT_DIR}/lib/docker_runtime.sh"
# shellcheck source=bin/lib/stack_helpers.sh
source "${SCRIPT_DIR}/lib/stack_helpers.sh"

show_usage() {
  cat <<EOF
Uso: $(basename "$0") [servicios]

Servicios disponibles:
  client
  employee
  all (por defecto)

Ejemplos:
  $(basename "$0")
  $(basename "$0") client employee
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
  [[ -f "${SECRETS_FILE}" ]] && COMPOSE_CMD+=(--env-file "${SECRETS_FILE}")
fi

echo "🛑 Deteniendo servicios: ${SERVICES[*]}"
"${COMPOSE_CMD[@]}" stop -t 10 "${SERVICES[@]}" 2>/dev/null || true
"${COMPOSE_CMD[@]}" rm -f -s "${SERVICES[@]}" 2>/dev/null || true

echo "✅ Servicios detenidos."
