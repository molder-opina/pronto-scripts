#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BASE_ENV_FILE="${PROJECT_ROOT}/.env"
ENV_FILE="$(mktemp -t pronto.env.XXXXXX)"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"
LIB_FILE="${SCRIPT_DIR}/lib/stack_helpers.sh"
LOAD_SEED=false
WITH_STATIC=false
WITH_STATIC_REQUESTED=false

# shellcheck source=bin/lib/docker_runtime.sh
source "${SCRIPT_DIR}/lib/docker_runtime.sh"

# shellcheck source=bin/lib/stack_helpers.sh
source "${LIB_FILE}"

# shellcheck source=bin/lib/static_helpers.sh
source "${SCRIPT_DIR}/lib/static_helpers.sh"

# shellcheck source=bin/lib/os_detect.sh
source "${SCRIPT_DIR}/lib/os_detect.sh"


# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --seed)
            LOAD_SEED=true
            shift
            ;;
        --with-static)
            WITH_STATIC_REQUESTED=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

block_static_args() {
    local arg
    local next_arg
    while [[ $# -gt 0 ]]; do
        arg="$1"
        next_arg="${2:-}"
        case "${arg}" in
            static|client|employee)
                echo "❌ No se permiten servicios como argumentos. Usa bin/up.sh sin servicios."
                exit 1
                ;;
            --profile)
                if [[ "${next_arg}" == "static" ]]; then
                    echo "❌ El perfil 'static' está deshabilitado en este entorno."
                    exit 1
                fi
                shift
                ;;
        esac
        shift
    done
}

block_static_args "$@"

if [[ "${WITH_STATIC_REQUESTED}" == true ]]; then
    echo "⚠️  Ignorando --with-static: el servicio static esta deshabilitado en este entorno."
    WITH_STATIC=false
fi

cleanup_env_file() {
    rm -f "${ENV_FILE}"
}

restore_seed_flag() {
    if [[ "${LOAD_SEED:-false}" == true && -f "${ENV_FILE}" ]]; then
        sed_inplace 's/^LOAD_SEED_DATA=.*/LOAD_SEED_DATA=false/' "${ENV_FILE}" || true
    fi
}
trap 'restore_seed_flag; cleanup_env_file' EXIT

echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║      🚀 INICIANDO PRONTO (Modo Normal) 🚀            ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

if [ "$LOAD_SEED" = true ]; then
    echo "📦 Modo de carga de datos activado (--seed)"
    echo "   Se cargarán/actualizarán 94+ productos de prueba"
    echo ""
fi

if [[ ! -f "${BASE_ENV_FILE}" ]]; then
    echo "❌ No se encontró ${BASE_ENV_FILE}. Revisa .env antes de continuar."
    exit 1
fi

cp "${BASE_ENV_FILE}" "${ENV_FILE}"
echo "✅ Configuración base cargada desde .env"
echo ""
echo "⚙️  Ajustando configuración a modo normal..."
sed_inplace 's/^DEBUG_MODE=.*/DEBUG_MODE=false/' "${ENV_FILE}"
sed_inplace 's/^FLASK_DEBUG=.*/FLASK_DEBUG=false/' "${ENV_FILE}"
sed_inplace 's/^LOG_LEVEL=.*/LOG_LEVEL=INFO/' "${ENV_FILE}"
echo "✅ Modo normal configurado"
echo ""

if [ "$LOAD_SEED" = true ]; then
    echo "🔧 Habilitando LOAD_SEED_DATA temporalmente..."
    sed_inplace 's/^LOAD_SEED_DATA=.*/LOAD_SEED_DATA=true/' "${ENV_FILE}"
fi

set -a
# shellcheck source=/dev/null
source "${ENV_FILE}"
set +a

CLIENT_PORT="${CLIENT_APP_HOST_PORT:-6080}"
EMPLOYEE_PORT="${EMPLOYEE_APP_HOST_PORT:-6081}"
STATIC_PORT="${STATIC_APP_HOST_PORT:-9088}"
APP_NAME_VALUE="${APP_NAME:-pronto}"
SERVICE_TARGETS=(
    "Clientes|${APP_NAME_VALUE}-client"
    "Empleados|${APP_NAME_VALUE}-employees"
)

COMPOSE_SERVICES=(client employees)
if [[ "${WITH_STATIC}" == true ]]; then
    SERVICE_TARGETS+=("Estático|${APP_NAME_VALUE}-static")
    COMPOSE_SERVICES+=(static)
fi

detect_compose_command "${COMPOSE_FILE}"
if [[ " ${COMPOSE_CMD[*]} " != *" --env-file "* ]]; then
    COMPOSE_CMD+=(--env-file "${ENV_FILE}")
fi

echo "🛑 Deteniendo contenedores existentes..."
"${COMPOSE_CMD[@]}" down --remove-orphans 2>/dev/null || true
echo ""

echo "🧪 Verificando puertos disponibles..."
PORT_CHECKS=(
    "${CLIENT_PORT}|App Clientes (http://localhost:${CLIENT_PORT})"
    "${EMPLOYEE_PORT}|App Empleados (http://localhost:${EMPLOYEE_PORT})"
)
if [[ "${WITH_STATIC}" == true ]]; then
    PORT_CHECKS+=("${STATIC_PORT}|Contenido estático (http://localhost:${STATIC_PORT})")
fi
ensure_ports_free "${PORT_CHECKS[@]}"
echo ""

echo "🚀 Iniciando servicios en modo normal..."
"${COMPOSE_CMD[@]}" up -d "$@" "${COMPOSE_SERVICES[@]}"

echo ""
echo "⏳ Esperando a que los servicios estén listos..."
if [ "$LOAD_SEED" = true ]; then
    echo "   (Esperando 30 segundos para que se carguen los datos...)"
    sleep 30
else
    sleep 10
fi

if [ "$LOAD_SEED" = true ]; then
    echo "🔧 Restaurando LOAD_SEED_DATA=false en entorno temporal..."
    sed_inplace 's/^LOAD_SEED_DATA=.*/LOAD_SEED_DATA=false/' "${ENV_FILE}"
fi

# Validar que el servidor de contenido estático esté disponible
validate_static_pod || echo "   ⚠️  Continuar sin validación de contenido estático"


echo ""
echo "📊 Estado de servicios:"
"${COMPOSE_CMD[@]}" ps

SERVICE_SUMMARY=()
FAILED_SERVICES=()
summarize_services "${CONTAINER_CLI}" SERVICE_SUMMARY FAILED_SERVICES "${SERVICE_TARGETS[@]}"

echo ""
echo "📦 Servicios clave:"
for line in "${SERVICE_SUMMARY[@]}"; do
    echo "   ${line}"
done

if ((${#FAILED_SERVICES[@]} > 0)); then
    echo ""
    echo "❌ Algunos servicios no arrancaron correctamente:"
    for fail in "${FAILED_SERVICES[@]}"; do
        echo "   • ${fail}"
    done
    echo ""
    echo "Revisa los logs con '${CONTAINER_CLI} logs <contenedor>' y corrige el error antes de reintentar."
    exit 1
fi

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║         ✅ SERVICIOS ACTIVOS (Modo Normal)           ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
echo "🌐 URLs disponibles:"
echo "   • App Empleados: http://localhost:${EMPLOYEE_PORT}"
echo "   • App Clientes:  http://localhost:${CLIENT_PORT}"
if [[ "${WITH_STATIC}" == true ]]; then
    echo "   • Estático:      http://localhost:${STATIC_PORT}"
fi
echo ""
echo "📝 Ver logs en tiempo real:"
echo "   ${CONTAINER_CLI} logs ${APP_NAME_VALUE}-employee -f"
echo "   ${CONTAINER_CLI} logs ${APP_NAME_VALUE}-client -f"
echo ""
echo "🔄 Para apagar la pila:"
echo "   bash bin/down.sh"
echo ""
