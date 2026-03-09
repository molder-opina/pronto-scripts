#!/usr/bin/env bash
# bin/mac/start.sh — Levanta servicios localmente en macOS con Docker Desktop
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"
source "${SCRIPT_DIR}/check-required-files.sh" 2>/dev/null || true
# shellcheck source=../../bin/lib/static-helpers.sh
source "${SCRIPT_DIR}/../lib/static-helpers.sh"
ENV_FILE="$(mktemp -t pronto.env.XXXXXX)"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"
LOAD_SEED=false
SERVICES=()

show_usage() {
    cat <<EOF
Uso: $(basename "$0") [servicios] [--seed]

Servicios disponibles:
  client
  employee
  api
  static
  all (por defecto - incluye todos)

Ejemplos:
  $(basename "$0")
  $(basename "$0") client
  $(basename "$0") client employee api --seed
  $(basename "$0") all --seed
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

if [[ ${#SERVICES[@]} -eq 0 ]]; then
    SERVICES=(client employee api static)
fi

echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║      🚀 PRONTO LOCAL (macOS/Docker Desktop)          ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

if [[ "$LOAD_SEED" = true ]]; then
    echo "📦 Modo de carga de datos activado (--seed)"
    echo "   Se cargarán/actualizarán 94+ productos de prueba"
    echo ""
fi

cleanup_env_file() {
    rm -f "${ENV_FILE}"
}
trap cleanup_env_file EXIT

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "❌ No se encontró ${ENV_FILE}"
    exit 1
fi

cp "${ENV_FILE}" "${ENV_FILE}"

# Load environment variables
set -a
# shellcheck source=../../.env
source "${ENV_FILE}"
set +a

if [[ "$LOAD_SEED" = true ]]; then
    echo "🔧 Habilitando LOAD_SEED_DATA temporalmente..."
    # macOS requiere '' después de -i para sed
    sed -i '' 's/^LOAD_SEED_DATA=.*/LOAD_SEED_DATA=true/' "${ENV_FILE}"
fi

CLIENT_PORT="${CLIENT_APP_HOST_PORT:-6080}"
EMPLOYEE_PORT="${EMPLOYEE_APP_HOST_PORT:-6081}"
API_PORT="${API_APP_HOST_PORT:-6082}"
STATIC_PORT="${STATIC_APP_HOST_PORT:-9088}"
APP_NAME_VALUE="${APP_NAME:-pronto}"

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-pronto}"
COMPOSE_CMD=(docker compose -f "${COMPOSE_FILE}" -p "${COMPOSE_PROJECT_NAME}" --env-file "${ENV_FILE}")

echo "🛑 Deteniendo servicios existentes..."
# We try to stop all services if none specified or if they are in the list
"${COMPOSE_CMD[@]}" stop -t 10 "${SERVICES[@]}" 2>/dev/null || true
"${COMPOSE_CMD[@]}" rm -f -s "${SERVICES[@]}" 2>/dev/null || true
echo ""

echo "🧪 Verificando puertos disponibles..."
check_port() {
    local port=$1
    local service=$2
    if lsof -Pi :${port} -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "❌ Puerto ${port} (${service}) ya está en uso"
        echo "   Proceso usando el puerto:"
        lsof -Pi :${port} -sTCP:LISTEN
        # Optional: Ask user to kill? But in non-interactive we just warn/exit.
        # Since this script handles restart, maybe we ignore?
        # But if it's NOT a docker container?
        # Assuming Docker handles port conflicts cleanly if we removed containers.
        # If lsof sees it, it might be zombie or another app.
        exit 1
    else
        echo "   ✅ Puerto ${port} disponible (${service})"
    fi
}

for service in "${SERVICES[@]}"; do
    case "$service" in
        client) check_port "${CLIENT_PORT}" "App Clientes" ;;
        employee) check_port "${EMPLOYEE_PORT}" "App Empleados" ;;
        api) check_port "${API_PORT}" "API Unificada" ;;
        static) check_port "${STATIC_PORT}" "Servidor Estático" ;;
    esac
done
echo ""

echo "🚀 Iniciando servicios..."
"${COMPOSE_CMD[@]}" up -d "${SERVICES[@]}"

echo ""
echo "⏳ Esperando a que los servicios estén listos..."
if [[ "$LOAD_SEED" = true ]]; then
    echo "   (Esperando 30 segundos para que se carguen los datos...)"
    sleep 30
else
    sleep 10
fi

echo ""
echo "📊 Estado de servicios:"
"${COMPOSE_CMD[@]}" ps "${SERVICES[@]}"

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║         ✅ SERVICIOS ACTIVOS                          ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
echo "🌐 URLs disponibles:"
for service in "${SERVICES[@]}"; do
    case "$service" in
        employee) echo "   • App Empleados: http://localhost:${EMPLOYEE_PORT}" ;;
        client) echo "   • App Clientes:  http://localhost:${CLIENT_PORT}" ;;
        api) echo "   • API Unificada: http://localhost:${API_PORT}" ;;
        static) echo "   • Servidor Estático: http://localhost:${STATIC_PORT}" ;;
    esac
done
echo ""
echo "📝 Ver logs en tiempo real:"
for service in "${SERVICES[@]}"; do
    echo "   docker logs ${APP_NAME_VALUE}-${service} -f"
done
echo ""
echo "🔄 Para apagar:"
echo "   bash bin/mac/stop.sh ${SERVICES[*]}"
echo ""

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
