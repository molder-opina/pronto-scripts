#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Script: sync-static-content.sh
# Propósito: Sincronizar contenido estático compilado al servidor/static container
# Este script:
# 1. Compila los bundles JS/Vue si es necesario
# 2. Copia assets compilados a static_content/
# 3. Sube contenido al contenedor static o servidor nginx
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

# Cargar variables de entorno
source "${ROOT_DIR}/.env" 2>/dev/null || true

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    local level="$1"
    local message="$2"
    local color

    case "$level" in
        INFO)    color="${BLUE}" ;;
        OK)      color="${GREEN}" ;;
        WARN)    color="${YELLOW}" ;;
        ERROR)   color="${RED}" ;;
        STEP)    color="${CYAN}" ;;
        *)       color="${NC}" ;;
    esac

    echo -e "${color}[${level}]${NC} ${message}"
}

# Directorios
STATIC_CONTENT_DIR="${ROOT_DIR}/src/static_content"
STATIC_ASSETS_DIR="${STATIC_CONTENT_DIR}/assets"
CLIENT_JS_DIST="${ROOT_DIR}/src/pronto_clients/static/js/dist/clients"
EMPLOYEE_JS_DIST="${ROOT_DIR}/src/pronto_employees/static/js/dist/employees"

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN: Compilar bundles JavaScript
# ═══════════════════════════════════════════════════════════════════════════════

compile_js_bundles() {
    log STEP "Compilando bundles JavaScript..."

    local os
    os="$(uname -s)"

    # Cambiar al directorio del proyecto
    cd "${ROOT_DIR}"

    if [ ! -d "node_modules" ]; then
        log WARN "node_modules no encontrado, instalando..."
        npm install
    fi

    # Compilar bundle de clientes
    log INFO "Compilando bundle de clientes..."
    PRONTO_TARGET=clients npx vite build

    # Compilar bundle de empleados
    log INFO "Compilando bundle de empleados..."
    PRONTO_TARGET=employees npx vite build

    log OK "Bundles JavaScript compilados exitosamente"
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN: Copiar assets al directorio static_content
# ═══════════════════════════════════════════════════════════════════════════════

copy_assets_to_static() {
    log STEP "Copiando assets al directorio static_content..."

    mkdir -p "${STATIC_ASSETS_DIR}/js/employees"
    mkdir -p "${STATIC_ASSETS_DIR}/js/clients"
    mkdir -p "${STATIC_ASSETS_DIR}/css/employees"
    mkdir -p "${STATIC_ASSETS_DIR}/css/clients"
    mkdir -p "${STATIC_ASSETS_DIR}/branding"

    # Copiar bundles JS de clientes
    if [ -d "${CLIENT_JS_DIST}" ]; then
        log INFO "Copiando bundle de clientes..."
        cp -r "${CLIENT_JS_DIST}/"* "${STATIC_ASSETS_DIR}/js/clients/" 2>/dev/null || true
        log OK "Bundle de clientes copiado a js/clients/"
    else
        log WARN "Directorio de bundle de clientes no encontrado: ${CLIENT_JS_DIST}"
    fi

    # Copiar bundles JS de empleados
    if [ -d "${EMPLOYEE_JS_DIST}" ]; then
        log INFO "Copiando bundle de empleados..."
        cp -r "${EMPLOYEE_JS_DIST}/"* "${STATIC_ASSETS_DIR}/js/employees/" 2>/dev/null || true
        log OK "Bundle de empleados copiado a js/employees/"
    else
        log WARN "Directorio de bundle de empleados no encontrado: ${EMPLOYEE_JS_DIST}"
    fi

    # Copiar CSS de clientes
    if [ -d "${ROOT_DIR}/src/pronto_clients/static/css" ]; then
        log INFO "Copiando CSS de clientes..."
        cp -r "${ROOT_DIR}/src/pronto_clients/static/css/"* "${STATIC_ASSETS_DIR}/css/clients/" 2>/dev/null || true
    fi

    # Copiar CSS de empleados
    if [ -d "${ROOT_DIR}/src/pronto_employees/static/css" ]; then
        log INFO "Copiando CSS de empleados..."
        cp -r "${ROOT_DIR}/src/pronto_employees/static/css/"* "${STATIC_ASSETS_DIR}/css/employees/" 2>/dev/null || true
    fi

    # Copiar branding
    if [ -d "${ROOT_DIR}/src/shared/assets/branding" ]; then
        log INFO "Copiando branding..."
        cp -r "${ROOT_DIR}/src/shared/assets/branding/"* "${STATIC_ASSETS_DIR}/branding/" 2>/dev/null || true
    fi

    # Copiar JS vanilla de empleados (no compilados)
    log INFO "Copiando JS vanilla de empleados..."
    mkdir -p "${STATIC_ASSETS_DIR}/js/employees"
    for file in keyboard-shortcuts.js pagination.js realtime.js loading.js \
        notifications.js feedback_dashboard.js business_config.js roles_management.js \
        shortcuts_admin.js employees_manager_vanilla.js roles_manager_vanilla.js \
        reports.js; do
        if [ -f "${ROOT_DIR}/src/pronto_employees/static/js/${file}" ]; then
            cp -f "${ROOT_DIR}/src/pronto_employees/static/js/${file}" \
                "${STATIC_ASSETS_DIR}/js/employees/" 2>/dev/null || true
        fi
    done

    # Copiar JS vanilla de clientes (no compilados)
    log INFO "Copiando JS vanilla de clientes..."
    mkdir -p "${STATIC_ASSETS_DIR}/js/clients"
    for file in keyboard-shortcuts.js notifications.js; do
        if [ -f "${ROOT_DIR}/src/pronto_clients/static/js/${file}" ]; then
            cp -f "${ROOT_DIR}/src/pronto_clients/static/js/${file}" \
                "${STATIC_ASSETS_DIR}/js/clients/" 2>/dev/null || true
        fi
    done

    log OK "Assets copiados a static_content/"
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN: Subir contenido al servidor static (pod o nginx)
# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN: Subir contenido al servidor static (pod o nginx)
# ═══════════════════════════════════════════════════════════════════════════════

upload_to_static_server() {
    log STEP "Subiendo contenido al servidor static..."

    local os
    local static_url
    local container_name

    os="$(uname -s)"
    static_url="${PRONTO_STATIC_CONTAINER_HOST:-http://localhost:9088}"

    # Detectar si usar docker o pod
    if command -v docker &> /dev/null; then
        container_name=$(docker ps --format '{{.Names}}' | grep -E 'static|nginx' | head -1)
        if [ -z "$container_name" ]; then
            # Buscar en docker-compose
            container_name=$(docker ps -a --format '{{.Names}}' | grep -E 'static|nginx' | head -1)
        fi
    fi

    if [ -z "$container_name" ]; then
        log WARN "No se encontró contenedor static/nginx"
        log INFO "El contenido está disponible en: ${STATIC_CONTENT_DIR}"
        return 1
    fi

    log INFO "Contenedor detectado: ${container_name}"

    # Verificar que el contenedor está ejecutándose
    if ! docker ps --format '{{.Names}}' | grep -q "$container_name"; then
        log WARN "El contenedor ${container_name} no está ejecutándose"
        return 1
    fi

    # Crear directorios necesarios en el contenedor
    docker exec "$container_name" mkdir -p /usr/share/nginx/html/assets/js/employees
    docker exec "$container_name" mkdir -p /usr/share/nginx/html/assets/js/clients
    docker exec "$container_name" mkdir -p /usr/share/nginx/html/assets/css/employees
    docker exec "$container_name" mkdir -p /usr/share/nginx/html/assets/css/clients
    docker exec "$container_name" mkdir -p /usr/share/nginx/html/assets/branding
    docker exec "$container_name" mkdir -p /usr/share/nginx/html/assets/pronto/menu

    # Copiar JS de empleados
    log INFO "Copiando JS de empleados..."
    docker cp "${STATIC_ASSETS_DIR}/js/employees/." "$container_name:/usr/share/nginx/html/assets/js/employees/" 2>/dev/null || true

    # Copiar JS de clientes
    log INFO "Copiando JS de clientes..."
    docker cp "${STATIC_ASSETS_DIR}/js/clients/." "$container_name:/usr/share/nginx/html/assets/js/clients/" 2>/dev/null || true

    # Copiar CSS de empleados
    log INFO "Copiando CSS de empleados..."
    docker cp "${STATIC_ASSETS_DIR}/css/employees/." "$container_name:/usr/share/nginx/html/assets/css/employees/" 2>/dev/null || true

    # Copiar CSS de clientes
    log INFO "Copiando CSS de clientes..."
    docker cp "${STATIC_ASSETS_DIR}/css/clients/." "$container_name:/usr/share/nginx/html/assets/css/clients/" 2>/dev/null || true

    # Copiar branding
    log INFO "Copiando branding..."
    docker cp "${STATIC_ASSETS_DIR}/branding/." "$container_name:/usr/share/nginx/html/assets/branding/" 2>/dev/null || true

    # Copiar imágenes de productos (pronto/menu)
    if [ -d "${STATIC_ASSETS_DIR}/pronto/menu" ]; then
        log INFO "Copiando imágenes de productos..."
        docker cp "${STATIC_ASSETS_DIR}/pronto/menu/." "$container_name:/usr/share/nginx/html/assets/pronto/menu/" 2>/dev/null || true
    fi

    # Recargar nginx si está disponible
    docker exec "$container_name" nginx -s reload 2>/dev/null || true

    log OK "Contenido sincronizado con contenedor: ${container_name}"
    log INFO "URL del servidor: ${static_url}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN: Mostrar estado del contenido estático
# ═══════════════════════════════════════════════════════════════════════════════

show_status() {
    log INFO "Estado del contenido estático:"
    echo ""

    echo "  Directorios fuente:"
    echo "    - Static content: ${STATIC_CONTENT_DIR}"
    echo "    - Clients JS:    ${CLIENT_JS_DIST}"
    echo "    - Employee JS:   ${EMPLOYEE_JS_DIST}"
    echo ""

    echo "  Contenido en static_content/:"
    if [ -d "${STATIC_CONTENT_DIR}" ]; then
        echo "    Archivos: $(find "${STATIC_CONTENT_DIR}" -type f | wc -l)"
        echo "    Directorios: $(find "${STATIC_CONTENT_DIR}" -type d | wc -l)"
        echo "    Tamaño: $(du -sh "${STATIC_CONTENT_DIR}" 2>/dev/null | cut -f1)"
    fi
    echo ""

    echo "  JS Bundles:"
    if [ -d "${STATIC_ASSETS_DIR}/js" ]; then
        ls -lh "${STATIC_ASSETS_DIR}/js/"*.js 2>/dev/null | head -5 | while read -r line; do
            echo "    ${line}"
        done
    fi
    echo ""

    echo "  Configuración actual:"
    echo "    NGINX_HOST:        ${NGINX_HOST:-no definido}"
    echo "    NGINX_PORT:        ${NGINX_PORT:-no definido}"
    echo "    PRONTO_STATIC_CONTAINER_HOST: ${PRONTO_STATIC_CONTAINER_HOST:-no definido}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    local action="${1:-all}"

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║          Sincronización de Contenido Estático PRONTO                ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""

    # Cargar detector de host estático
    if [ -f "${SCRIPT_DIR}/static-host-detector.sh" ]; then
        source "${SCRIPT_DIR}/static-host-detector.sh" export 2>/dev/null || true
    fi

    log INFO "Entorno: $(uname -s)"
    log INFO "NGINX_HOST: ${NGINX_HOST:-localhost}"
    log INFO "NGINX_PORT: ${NGINX_PORT:-9088}"
    log INFO "PRONTO_STATIC_CONTAINER_HOST: ${PRONTO_STATIC_CONTAINER_HOST:-http://localhost:9088}"
    echo ""

    case "$action" in
        compile)
            compile_js_bundles
            ;;
        copy)
            copy_assets_to_static
            ;;
        upload)
            upload_to_static_server
            ;;
        all)
            compile_js_bundles
            echo ""
            copy_assets_to_static
            echo ""
            upload_to_static_server
            echo ""
            show_status
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            echo "Uso: $0 [comando]"
            echo ""
            echo "Comandos:"
            echo "  compile - Solo compilar bundles JavaScript"
            echo "  copy    - Solo copiar assets a static_content/"
            echo "  upload  - Solo subir contenido al servidor static"
            echo "  all     - Compilar, copiar y subir (defecto)"
            echo "  status  - Mostrar estado del contenido"
            echo "  help    - Mostrar esta ayuda"
            echo ""
            ;;
        *)
            log ERROR "Comando desconocido: ${action}"
            echo "Usa '$0 help' para ver la ayuda"
            exit 1
            ;;
    esac

    echo ""
    log OK "Sincronización completada"
}

main "$@"
