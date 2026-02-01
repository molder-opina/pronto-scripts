#!/usr/bin/env bash
# Pronto Container Guard - Mantiene los contenedores corriendo
# Este script monitorea y reinicia los contenedores si se caen

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/config/general.env"
LOG_DIR="${PROJECT_ROOT}/logs/systemd"
RUNTIME_LIB="${PROJECT_ROOT}/bin/lib/docker_runtime.sh"
STACK_HELPERS_LIB="${PROJECT_ROOT}/bin/lib/stack_helpers.sh"

# Crear directorio de logs si no existe
mkdir -p "${LOG_DIR}"

# Cargar variables de entorno
if [[ -f "${ENV_FILE}" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "${ENV_FILE}"
    set +a
fi

if [[ -f "${RUNTIME_LIB}" ]]; then
    # shellcheck source=/dev/null
    source "${RUNTIME_LIB}"
fi

if [[ -f "${STACK_HELPERS_LIB}" ]]; then
    # shellcheck source=/dev/null
    source "${STACK_HELPERS_LIB}"
fi

APP_NAME_VALUE="${APP_NAME:-pronto}"
CLIENT_CONTAINER="${APP_NAME_VALUE}-client"
EMPLOYEE_CONTAINER="${APP_NAME_VALUE}-employee"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"

if declare -F detect_compose_command >/dev/null 2>&1; then
    detect_compose_command "${COMPOSE_FILE}" >/dev/null
else
    CONTAINER_CLI="docker"
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

runtime_ready() {
    "${CONTAINER_CLI}" version >/dev/null 2>&1
}

container_status() {
    local container_name="$1"
    "${CONTAINER_CLI}" inspect -f '{{.State.Status}}' "${container_name}" 2>/dev/null || return 1
}

container_running() {
    local container_name="$1"
    local status
    status="$(container_status "${container_name}")" || return 1
    [[ "${status}" == "running" ]]
}

container_exists() {
    local container_name="$1"
    "${CONTAINER_CLI}" inspect "${container_name}" >/dev/null 2>&1
}

# Función para iniciar todos los servicios
start_all_services() {
    log "Iniciando servicios de Pronto..."

    cd "${PROJECT_ROOT}"

    # Usar el script up.sh para levantar los servicios
    if [[ -f "bin/up.sh" ]]; then
        bash bin/up.sh || {
            log "ERROR: No se pudieron iniciar los servicios"
            return 1
        }
    else
        log "ERROR: No se encontró bin/up.sh"
        return 1
    fi

    log "Servicios iniciados correctamente"
    return 0
}

# Función para reiniciar un contenedor específico
restart_container() {
    local container_name="$1"
    log "Reiniciando contenedor: ${container_name}"

    "${CONTAINER_CLI}" restart "${container_name}" || {
        log "ERROR: No se pudo reiniciar ${container_name}"
        return 1
    }

    log "Contenedor ${container_name} reiniciado"
    return 0
}

# Bucle principal de monitoreo
log "Pronto Guard iniciado"
log "Runtime detectado: ${CONTAINER_CLI}"
log "Monitoreando contenedores: ${CLIENT_CONTAINER}, ${EMPLOYEE_CONTAINER}"

# Esperar un poco antes de verificar (dar tiempo al sistema para iniciar)
sleep 30

# Verificar si los contenedores están corriendo al inicio
CONTAINERS_RUNNING=0
if runtime_ready \
    && container_running "${CLIENT_CONTAINER}" \
    && container_running "${EMPLOYEE_CONTAINER}"; then
    CONTAINERS_RUNNING=1
    log "Contenedores ya están corriendo"
fi

# Si no están corriendo, intentar iniciarlos
if [[ ${CONTAINERS_RUNNING} -eq 0 ]]; then
    log "Contenedores no están corriendo, iniciando servicios..."
    start_all_services || {
        log "FATAL: No se pudieron iniciar los servicios en el arranque"
        sleep 60
    }
fi

# Bucle de monitoreo continuo
while true; do
    sleep 60  # Verificar cada minuto

    if ! runtime_ready; then
        log "ERROR: No se puede acceder al runtime de contenedores (${CONTAINER_CLI}). Reintentando en 60s."
        continue
    fi

    # Verificar aplicación de clientes
    if ! container_running "${CLIENT_CONTAINER}"; then
        log "ALERTA: App de clientes no está corriendo"
        if container_exists "${CLIENT_CONTAINER}"; then
            restart_container "${CLIENT_CONTAINER}"
        else
            log "CRÍTICO: Contenedor de clientes no existe, reiniciando todo"
            start_all_services
        fi
    fi

    # Verificar aplicación de empleados
    if ! container_running "${EMPLOYEE_CONTAINER}"; then
        log "ALERTA: App de empleados no está corriendo"
        if container_exists "${EMPLOYEE_CONTAINER}"; then
            restart_container "${EMPLOYEE_CONTAINER}"
        else
            log "CRÍTICO: Contenedor de empleados no existe, reiniciando todo"
            start_all_services
        fi
    fi
done
