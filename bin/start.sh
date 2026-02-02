#!/usr/bin/env bash
# bin/start.sh — Levanta servicios localmente en Linux con Docker
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BASE_ENV_FILE="${PROJECT_ROOT}/.env"
SECRETS_FILE="${PROJECT_ROOT}/.env"
ENV_FILE="$(mktemp -t pronto.env.XXXXXX)"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"
LOAD_SEED=false
SERVICES=()

# shellcheck source=bin/lib/docker_runtime.sh
source "${SCRIPT_DIR}/lib/docker_runtime.sh"
# shellcheck source=bin/lib/stack_helpers.sh
source "${SCRIPT_DIR}/lib/stack_helpers.sh"
# shellcheck source=bin/lib/static_helpers.sh
source "${SCRIPT_DIR}/lib/static_helpers.sh"

show_usage() {
  cat <<EOF
Uso: $(basename "$0") [servicios] [--seed]

Servicios disponibles:
  client
  employee
  all (por defecto)

Ejemplos:
  $(basename "$0")
  $(basename "$0") client
  $(basename "$0") client employee --seed
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --seed)
      LOAD_SEED=true
      shift
      ;;
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

cleanup_env_file() {
  rm -f "${ENV_FILE}"
}
trap cleanup_env_file EXIT

if [[ ! -f "${BASE_ENV_FILE}" ]]; then
  echo "❌ No se encontró ${BASE_ENV_FILE}"
  exit 1
fi

cp "${BASE_ENV_FILE}" "${ENV_FILE}"

# Load environment variables
set -a
# shellcheck source=/dev/null
source "${BASE_ENV_FILE}"
# shellcheck source=/dev/null
[[ -f "${SECRETS_FILE}" ]] && source "${SECRETS_FILE}"
set +a

if [[ "$LOAD_SEED" = true ]]; then
  echo "🔧 Habilitando LOAD_SEED_DATA temporalmente..."
  sed -i 's/^LOAD_SEED_DATA=.*/LOAD_SEED_DATA=true/' "${ENV_FILE}"
fi

CLIENT_PORT="${CLIENT_APP_HOST_PORT:-6080}"
EMPLOYEE_PORT="${EMPLOYEE_APP_HOST_PORT:-6081}"
APP_NAME_VALUE="${APP_NAME:-pronto}"

detect_compose_command "${COMPOSE_FILE}"
if [[ " ${COMPOSE_CMD[*]} " != *" --env-file "* ]]; then
  COMPOSE_CMD+=(--env-file "${ENV_FILE}")
  [[ -f "${SECRETS_FILE}" ]] && COMPOSE_CMD+=(--env-file "${SECRETS_FILE}")
fi

echo "🛑 Deteniendo servicios existentes..."
"${COMPOSE_CMD[@]}" stop -t 10 "${SERVICES[@]}" 2>/dev/null || true
"${COMPOSE_CMD[@]}" rm -f -s "${SERVICES[@]}" 2>/dev/null || true
echo ""

echo "🧪 Verificando puertos disponibles..."
for service in "${SERVICES[@]}"; do
  case "$service" in
    client) ensure_ports_free "${CLIENT_PORT}|App Clientes" ;;
    employee) ensure_ports_free "${EMPLOYEE_PORT}|App Empleados" ;;
  esac
done
echo ""

echo "🚀 Iniciando servicios..."
"${COMPOSE_CMD[@]}" up -d "${SERVICES[@]}"

echo ""
echo "📊 Estado de servicios:"
"${COMPOSE_CMD[@]}" ps "${SERVICES[@]}"

echo ""
echo "🌐 URLs disponibles:"
for service in "${SERVICES[@]}"; do
  case "$service" in
    employee) echo "   • App Empleados: http://localhost:${EMPLOYEE_PORT}" ;;
    client) echo "   • App Clientes:  http://localhost:${CLIENT_PORT}" ;;
  esac
done

echo ""
echo "📝 Ver logs en tiempo real:"
for service in "${SERVICES[@]}"; do
  echo "   ${CONTAINER_CLI} logs ${APP_NAME_VALUE}-${service} -f"
done

echo ""
echo "🔄 Para apagar:"
echo "   bash bin/stop.sh ${SERVICES[*]}"

# Validate static pod (for client and employee services)
NEEDS_STATIC_VALIDATION=false
for service in "${SERVICES[@]}"; do
  if [[ "$service" == "client" || "$service" == "employee" ]]; then
    NEEDS_STATIC_VALIDATION=true
    break
  fi
done

if [[ "$NEEDS_STATIC_VALIDATION" == "true" ]]; then
  validate_static_pod || echo "   ⚠️  Continuar sin validación de contenido estático"
fi
