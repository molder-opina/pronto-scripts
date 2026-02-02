#!/usr/bin/env bash
# bin/mac/up-debug.sh — Levanta servicios en modo DEBUG en macOS con Docker Desktop
# Habilita autocompletado de formularios y logs detallados

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE_SRC="${PROJECT_ROOT}/.env"
ENV_FILE="$(mktemp -t pronto.env.XXXXXX)"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"
LOAD_SEED=false

show_usage() {
    cat <<EOF
Uso: $(basename "$0") [--seed]

Opciones:
  --seed    Cargar datos de prueba (94+ productos)
  -h        Mostrar esta ayuda

Ejemplos:
  $(basename "$0")
  $(basename "$0") --seed
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --seed)
            LOAD_SEED=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Opcion desconocida: $1"
            show_usage
            exit 1
            ;;
    esac
done

cleanup_env_file() {
    rm -f "${ENV_FILE}"
}

restore_seed_flag() {
    if [[ "${LOAD_SEED:-false}" == true && -f "${ENV_FILE}" ]]; then
        # macOS requiere '' despues de -i para sed
        sed -i '' 's/^LOAD_SEED_DATA=.*/LOAD_SEED_DATA=false/' "${ENV_FILE}" 2>/dev/null || true
    fi
}
trap 'restore_seed_flag; cleanup_env_file' EXIT

echo ""
echo "======================================================="
echo "                                                       "
echo "   INICIANDO PRONTO EN MODO DEBUG (macOS)             "
echo "                                                       "
echo "======================================================="
echo ""

if [[ "$LOAD_SEED" = true ]]; then
    echo "Modo de carga de datos activado (--seed)"
    echo "   Se cargaran/actualizaran 94+ productos de prueba"
    echo ""
fi

# Verificar que el archivo de configuracion existe
if [[ ! -f "${ENV_FILE_SRC}" ]]; then
    echo "Error: ${ENV_FILE_SRC} no encontrado"
    exit 1
fi

echo "Configurando modo DEBUG..."

cp "${ENV_FILE_SRC}" "${ENV_FILE}"
echo "Configuracion base cargada desde .env"

# Modificar entorno temporal para modo debug (macOS sed syntax)
sed -i '' 's/^DEBUG_MODE=.*/DEBUG_MODE=true/' "${ENV_FILE}" 2>/dev/null || true
sed -i '' 's/^FLASK_DEBUG=.*/FLASK_DEBUG=true/' "${ENV_FILE}" 2>/dev/null || true
sed -i '' 's/^LOG_LEVEL=.*/LOG_LEVEL=DEBUG/' "${ENV_FILE}" 2>/dev/null || true
sed -i '' 's/^DEBUG_AUTO_TABLE=.*/DEBUG_AUTO_TABLE=true/' "${ENV_FILE}" 2>/dev/null || true

# Enable seed data loading if --seed flag was provided
if [[ "$LOAD_SEED" = true ]]; then
    sed -i '' 's/^LOAD_SEED_DATA=.*/LOAD_SEED_DATA=true/' "${ENV_FILE}"
fi

echo "Modo DEBUG activado en entorno temporal"
echo "   - DEBUG_MODE=true (Botones de prellenado habilitados)"
echo "   - FLASK_DEBUG=true (Logs detallados)"
echo "   - LOG_LEVEL=DEBUG (Informacion completa)"
echo "   - DEBUG_AUTO_TABLE=true (Mesa 1 auto-asignada para pruebas)"
if [[ "$LOAD_SEED" = true ]]; then
    echo "   - LOAD_SEED_DATA=true (Datos de prueba habilitados)"
fi
echo ""

# Load environment variables
set -a
# shellcheck source=../../.env
source "${ENV_FILE_SRC}"
set +a

CLIENT_PORT="${CLIENT_APP_HOST_PORT:-6080}"
EMPLOYEE_PORT="${EMPLOYEE_APP_HOST_PORT:-6081}"
STATIC_PORT="${STATIC_APP_HOST_PORT:-9088}"
APP_NAME_VALUE="${APP_NAME:-pronto}"

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-pronto}"
COMPOSE_CMD=(docker compose -f "${COMPOSE_FILE}" -p "${COMPOSE_PROJECT_NAME}" --env-file "${ENV_FILE}")

# Detener contenedores si estan corriendo
echo "Deteniendo contenedores existentes..."
"${COMPOSE_CMD[@]}" down 2>/dev/null || true
echo ""

echo "Verificando puertos disponibles..."
check_port() {
    local port=$1
    local service=$2
    if lsof -Pi :${port} -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "Puerto ${port} (${service}) ya esta en uso"
        echo "   Proceso usando el puerto:"
        lsof -Pi :${port} -sTCP:LISTEN
        exit 1
    else
        echo "   Puerto ${port} disponible (${service})"
    fi
}

check_port "${CLIENT_PORT}" "App Clientes"
check_port "${EMPLOYEE_PORT}" "App Empleados"
check_port "${STATIC_PORT}" "Servidor Estatico"
echo ""

# Levantar servicios en modo debug
echo "Levantando servicios en modo DEBUG..."
"${COMPOSE_CMD[@]}" up -d

# Esperar a que los servicios esten listos
echo ""
echo "Esperando a que los servicios esten listos..."
if [[ "$LOAD_SEED" = true ]]; then
    echo "   (Esperando 30 segundos para que se carguen los datos...)"
    sleep 30
else
    sleep 15
fi

# Restore LOAD_SEED_DATA to false after services start
if [[ "$LOAD_SEED" = true ]]; then
    echo "Restaurando LOAD_SEED_DATA=false en entorno temporal..."
    sed -i '' 's/^LOAD_SEED_DATA=.*/LOAD_SEED_DATA=false/' "${ENV_FILE}"
fi

# Verificar estado
echo ""
echo "Estado de servicios:"
"${COMPOSE_CMD[@]}" ps

# Check if services are running
FAILED_SERVICES=()
for service in client employee; do
    container="${APP_NAME_VALUE}-${service}"
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        FAILED_SERVICES+=("${container}")
    fi
done

if [[ ${#FAILED_SERVICES[@]} -gt 0 ]]; then
    echo ""
    echo "Algunos servicios no arrancaron correctamente:"
    for fail in "${FAILED_SERVICES[@]}"; do
        echo "   - ${fail}"
    done
    echo ""
    echo "Revisa los logs con 'docker logs <contenedor>' y corrige el error antes de reintentar."
    exit 1
fi

echo ""
echo "======================================================="
echo "                                                       "
echo "   SERVICIOS EN MODO DEBUG ACTIVOS                    "
echo "                                                       "
echo "======================================================="
echo ""
echo "URLs disponibles:"
echo "   - App Empleados: http://localhost:${EMPLOYEE_PORT}"
echo "   - App Clientes:  http://localhost:${CLIENT_PORT}"
echo "   - Servidor Estatico: http://localhost:${STATIC_PORT}"
echo ""
echo "Caracteristicas DEBUG habilitadas:"
echo "   - Botones de prellenado en formularios"
echo "   - Logs detallados en consola"
echo "   - Informacion de debug visible"
echo ""
echo "Credenciales de prueba:"
echo "   - Super Admin: admin@cafeteria.test"
echo "   - Chef:        carlos.chef@cafeteria.test"
echo "   - Mesero:      juan.mesero@cafeteria.test"
echo "   - Cajero:      laura.cajera@cafeteria.test"
echo "   - Password:    ChangeMe!123"
echo ""
echo "Ver logs en tiempo real:"
echo "   docker logs ${APP_NAME_VALUE}-employee -f"
echo "   docker logs ${APP_NAME_VALUE}-client -f"
echo ""
echo "Para volver al modo normal:"
echo "   bash bin/mac/down.sh"
echo "   bash bin/mac/start.sh"
echo ""
