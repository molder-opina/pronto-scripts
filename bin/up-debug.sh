#!/usr/bin/env bash
# Script para levantar los servicios en modo DEBUG
# Habilita autocompletado de formularios y logs detallados

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE_SRC="${PROJECT_ROOT}/.env"
ENV_FILE="$(mktemp -t pronto.env.XXXXXX)"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"
LIB_FILE="${PROJECT_ROOT}/bin/lib/stack_helpers.sh"
LOAD_SEED=false

# shellcheck source=bin/lib/docker_runtime.sh
source "${SCRIPT_DIR}/lib/docker_runtime.sh"

# shellcheck source=bin/lib/stack_helpers.sh
source "${LIB_FILE}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --seed)
            LOAD_SEED=true
            shift
            ;;
        *)
            # Pass through other arguments
            break
            ;;
    esac
done

cleanup_env_file() {
    rm -f "${ENV_FILE}"
}

restore_seed_flag() {
    if [[ "${LOAD_SEED:-false}" == true && -f "${ENV_FILE}" ]]; then
        sed -i 's/^LOAD_SEED_DATA=.*/LOAD_SEED_DATA=false/' "${ENV_FILE}" || true
    fi
}
trap 'restore_seed_flag; cleanup_env_file' EXIT

echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║   🐛 INICIANDO PRONTO EN MODO DEBUG 🐛               ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

if [ "$LOAD_SEED" = true ]; then
    echo "📦 Modo de carga de datos activado (--seed)"
    echo "   Se cargarán/actualizarán 94+ productos de prueba"
    echo ""
fi

# Verificar que el archivo de configuración existe
if [[ ! -f "${ENV_FILE_SRC}" ]]; then
    echo "❌ Error: ${ENV_FILE_SRC} no encontrado"
    exit 1
fi

echo "🔧 Configurando modo DEBUG..."

cp "${ENV_FILE_SRC}" "${ENV_FILE}"
echo "✅ Configuración base cargada desde .env"

# Modificar entorno temporal para modo debug
sed -i.bak 's/^DEBUG_MODE=.*/DEBUG_MODE=true/' "${ENV_FILE}" || true
sed -i.bak 's/^FLASK_DEBUG=.*/FLASK_DEBUG=true/' "${ENV_FILE}" || true
sed -i.bak 's/^LOG_LEVEL=.*/LOG_LEVEL=DEBUG/' "${ENV_FILE}" || true
sed -i.bak 's/^DEBUG_AUTO_TABLE=.*/DEBUG_AUTO_TABLE=true/' "${ENV_FILE}" || true
rm -f "${ENV_FILE}.bak" 2>/dev/null || true

# Enable seed data loading if --seed flag was provided
if [ "$LOAD_SEED" = true ]; then
    sed -i 's/^LOAD_SEED_DATA=.*/LOAD_SEED_DATA=true/' "${ENV_FILE}"
fi

echo "✅ Modo DEBUG activado en entorno temporal"
echo "   • DEBUG_MODE=true (Botones de prellenado habilitados)"
echo "   • FLASK_DEBUG=true (Logs detallados)"
echo "   • LOG_LEVEL=DEBUG (Información completa)"
echo "   • DEBUG_AUTO_TABLE=true (Mesa 1 auto-asignada para pruebas)"
if [ "$LOAD_SEED" = true ]; then
    echo "   • LOAD_SEED_DATA=true (Datos de prueba habilitados)"
fi
echo ""

set -a
# shellcheck source=/dev/null
source "${ENV_FILE}"
set +a

CLIENT_PORT="${CLIENT_APP_HOST_PORT:-6080}"
EMPLOYEE_PORT="${EMPLOYEE_APP_HOST_PORT:-6081}"
APP_NAME_VALUE="${APP_NAME:-pronto}"
SERVICE_TARGETS=(
    "Clientes|${APP_NAME_VALUE}-client"
    "Empleados|${APP_NAME_VALUE}-employee"
)

detect_compose_command "${COMPOSE_FILE}"
if [[ " ${COMPOSE_CMD[*]} " != *" --env-file "* ]]; then
    COMPOSE_CMD+=(--env-file "${ENV_FILE}")
fi

# Detener contenedores si están corriendo
echo "🛑 Deteniendo contenedores existentes..."
"${COMPOSE_CMD[@]}" down 2>/dev/null || true
echo ""

echo "🧪 Verificando puertos disponibles..."
ensure_ports_free \
    "${CLIENT_PORT}|App Clientes (http://localhost:${CLIENT_PORT})" \
    "${EMPLOYEE_PORT}|App Empleados (http://localhost:${EMPLOYEE_PORT})"
echo ""

# Levantar servicios en modo debug
echo "🚀 Levantando servicios en modo DEBUG..."
"${COMPOSE_CMD[@]}" up -d

# Esperar a que los servicios estén listos
echo ""
echo "⏳ Esperando a que los servicios estén listos..."
if [ "$LOAD_SEED" = true ]; then
    echo "   (Esperando 30 segundos para que se carguen los datos...)"
    sleep 30
else
    sleep 15
fi

# Restore LOAD_SEED_DATA to false after services start
if [ "$LOAD_SEED" = true ]; then
    echo "🔧 Restaurando LOAD_SEED_DATA=false en entorno temporal..."
    sed -i 's/^LOAD_SEED_DATA=.*/LOAD_SEED_DATA=false/' "${ENV_FILE}"
fi

# Verificar estado
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
echo "║   ✅ SERVICIOS EN MODO DEBUG ACTIVOS                 ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
echo "🌐 URLs disponibles:"
echo "   • App Empleados: http://localhost:${EMPLOYEE_PORT}"
echo "   • App Clientes:  http://localhost:${CLIENT_PORT}"
echo ""
echo "🐛 Características DEBUG habilitadas:"
echo "   • 🎯 Botones de prellenado en formularios"
echo "   • 📝 Logs detallados en consola"
echo "   • 🔍 Información de debug visible"
echo ""
echo "👤 Credenciales de prueba:"
echo "   • Super Admin: admin@cafeteria.test"
echo "   • Chef:        carlos.chef@cafeteria.test"
echo "   • Mesero:      juan.mesero@cafeteria.test"
echo "   • Cajero:      laura.cajera@cafeteria.test"
echo "   • Password:    ChangeMe!123"
echo ""
echo "📝 Ver logs en tiempo real:"
echo "   ${CONTAINER_CLI} logs ${APP_NAME_VALUE}-employee -f"
echo "   ${CONTAINER_CLI} logs ${APP_NAME_VALUE}-client -f"
echo ""
echo "🔄 Para volver al modo normal:"
echo "   bash bin/down.sh"
echo "   bash bin/up.sh"
echo ""
