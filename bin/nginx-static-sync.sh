#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Script: nginx-static-sync.sh
# Propósito: Sincronizar contenido estático compilado a nginx local
# Uso:
#   ./nginx-static-sync.sh sync    - Sincronizar contenido a nginx
#   ./nginx-static-sync.sh status  - Mostrar estado de nginx y contenido
#   ./nginx-static-sync.sh detect  - Detectar ubicación de nginx
#   ./nginx-static-sync.sh test    - Probar configuración de nginx
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
REPO_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/.env"

# Cargar variables de entorno existentes
source "${CONFIG_FILE}" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════════
# Configuración (desde variables de entorno o valores por defecto)
# ═══════════════════════════════════════════════════════════════════════════════

NGINX_HOST="${NGINX_HOST:-localhost}"
NGINX_PORT="${NGINX_PORT:-9088}"
NGINX_PREFIX="${NGINX_PREFIX:-}"
NGINX_USER="${NGINX_USER:-root}"
STATIC_CONTENT_DIR="${REPO_ROOT}/pronto-static/src/static_content"
VERIFY_SSL="${VERIFY_SSL:-false}"

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

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN: Detectar ubicación de nginx
# ═══════════════════════════════════════════════════════════════════════════════

detect_nginx() {
    log STEP "Detectando instalación de nginx..."

    local nginx_path=""
    local nginx_prefix=""
    local nginx_conf=""
    local detected=false

    # 1. Verificar variable NGINX_PREFIX explícita
    if [ -n "${NGINX_PREFIX:-}" ] && [ -d "${NGINX_PREFIX}" ]; then
        log INFO "Usando NGINX_PREFIX explícito: ${NGINX_PREFIX}"
        nginx_prefix="${NGINX_PREFIX}"
        detected=true
    fi

    # 2. Buscar nginx en PATH
    if [ -z "$nginx_prefix" ]; then
        nginx_path=$(command -v nginx 2>/dev/null || true)
        if [ -n "$nginx_path" ]; then
            log INFO "nginx encontrado en: ${nginx_path}"

            # Obtener prefix desde nginx -V
            nginx_prefix=$(nginx -V 2>&1 | grep -oP '(?<=--prefix=)\S+' | head -1 || true)

            if [ -n "$nginx_prefix" ]; then
                log INFO "nginx prefix: ${nginx_prefix}"
                detected=true
            fi
        fi
    fi

    # 3. Buscar ubicaciones comunes
    if [ -z "$nginx_prefix" ]; then
        local common_paths=(
            "/usr/local/nginx"
            "/etc/nginx"
            "/opt/homebrew/nginx"
            "/usr/local/opt/nginx"
        )

        for path in "${common_paths[@]}"; do
            if [ -d "$path" ] && [ -f "${path}/conf/nginx.conf" ]; then
                nginx_prefix="$path"
                log INFO "nginx encontrado en ubicación común: ${nginx_prefix}"
                detected=true
                break
            fi
        done
    fi

    # 4. Verificar si hay un proceso nginx ejecutándose
    if [ -z "$nginx_prefix" ]; then
        if pgrep -x nginx > /dev/null 2>&1; then
            log INFO "nginx está ejecutándose, detectando prefix..."

            # Intentar obtener el prefix del proceso
            nginx_prefix=$(ps aux | grep nginx | grep -v grep | head -1 | awk '{print $11}' | xargs dirname 2>/dev/null || true)

            if [ -n "$nginx_prefix" ]; then
                log INFO "nginx prefix (desde proceso): ${nginx_prefix}"
                detected=true
            fi
        fi
    fi

    if [ "$detected" = true ] && [ -n "$nginx_prefix" ]; then
        nginx_conf="${nginx_prefix}/conf/nginx.conf"

        if [ -f "$nginx_conf" ]; then
            log OK "nginx detectado: ${nginx_prefix}"
            echo "NGINX_PREFIX=${nginx_prefix}"
            echo "NGINX_CONF=${nginx_conf}"
            echo "NGINX_HTML_DIR=${nginx_prefix}/html"
            return 0
        fi
    fi

    log WARN "nginx no detectado automáticamente"
    echo "NGINX_PREFIX="
    echo "NGINX_CONF="
    echo "NGINX_HTML_DIR="
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN: Actualizar general.env con variables de nginx
# ═══════════════════════════════════════════════════════════════════════════════

update_nginx_env() {
    log STEP "Actualizando .env con variables de nginx..."

    local nginx_prefix="$1"
    local nginx_host="${NGINX_HOST:-localhost}"
    local nginx_port="${NGINX_PORT:-9088}"

    if [ -z "$nginx_prefix" ]; then
        log WARN "No hay prefix de nginx para actualizar"
        return 1
    fi

    # Crear backup
    cp "${CONFIG_FILE}" "${CONFIG_FILE}.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

    # Actualizar o agregar variables
    local temp_file
    temp_file=$(mktemp)

    # Leer archivo original y modificar
    while IFS= read -r line; do
        if [[ "$line" =~ ^NGINX_ ]]; then
            # Saltar líneas de nginx existentes
            continue
        elif [[ "$line" == "# Nginx Configuration" ]]; then
            # Mantener el header y agregar nuevas variables
            cat <<EOF
# Nginx Configuration
NGINX_PREFIX=${nginx_prefix}
NGINX_HOST=${nginx_host}
NGINX_PORT=${nginx_port}
NGINX_USER=${NGINX_USER:-root}

EOF
            echo "$line"
        else
            echo "$line"
        fi
    done < "$CONFIG_FILE" > "$temp_file"

    # Si no existe el header, agregarlo al final
    if ! grep -q "# Nginx Configuration" "$temp_file"; then
        cat >> "$temp_file" <<EOF

# Nginx Configuration
NGINX_PREFIX=${nginx_prefix}
NGINX_HOST=${nginx_host}
NGINX_PORT=${nginx_port}
NGINX_USER=${NGINX_USER:-root}
EOF
    fi

    mv "$temp_file" "$CONFIG_FILE"

    log OK "Archivo de configuración actualizado: ${CONFIG_FILE}"
    log INFO "NGINX_PREFIX=${nginx_prefix}"
    log INFO "NGINX_HOST=${nginx_host}"
    log INFO "NGINX_PORT=${nginx_port}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN: Sincronizar contenido a nginx
# ═══════════════════════════════════════════════════════════════════════════════

sync_to_nginx() {
    log STEP "Sincronizando contenido estático a nginx..."

    local nginx_prefix="${NGINX_PREFIX:-}"
    local nginx_html_dir=""

    # Detectar nginx si no está configurado
    if [ -z "$nginx_prefix" ]; then
        log INFO "NGINX_PREFIX no configurado, detectando..."
        nginx_prefix=$(detect_nginx | grep "NGINX_PREFIX=" | cut -d= -f2 || true)
    fi

    if [ -z "$nginx_prefix" ]; then
        log ERROR "No se puede sincronizar: nginx no detectado"
        log INFO "Ejecuta './nginx-static-sync.sh detect' primero"
        return 1
    fi

    nginx_html_dir="${nginx_prefix}/html"

    if [ ! -d "$nginx_html_dir" ]; then
        log ERROR "Directorio html de nginx no encontrado: ${nginx_html_dir}"
        return 1
    fi

    if [ ! -d "$STATIC_CONTENT_DIR" ]; then
        log ERROR "Directorio de contenido estático no encontrado: ${STATIC_CONTENT_DIR}"
        return 1
    fi

    log INFO "Origen: ${STATIC_CONTENT_DIR}"
    log INFO "Destino: ${nginx_html_dir}"

    # Verificar permisos
    if [ ! -w "$nginx_html_dir" ]; then
        log WARN "No hay permisos de escritura en ${nginx_html_dir}"
        log INFO "Intentando con sudo..."

        # Usar rsync con sudo
        if command -v rsync &> /dev/null; then
            sudo rsync -av --delete "${STATIC_CONTENT_DIR}/" "${nginx_html_dir}/"
        else
            # Usar cp como fallback
            sudo cp -r "${STATIC_CONTENT_DIR}/"* "${nginx_html_dir}/"
        fi
    else
        # Sincronización normal
        if command -v rsync &> /dev/null; then
            rsync -av --delete "${STATIC_CONTENT_DIR}/" "${nginx_html_dir}/"
        else
            cp -r "${STATIC_CONTENT_DIR}/"* "${nginx_html_dir}/"
        fi
    fi

    log OK "Contenido sincronizado a: ${nginx_html_dir}"

    # Recargar nginx si está ejecutándose
    if pgrep -x nginx > /dev/null 2>&1; then
        log INFO "Recargando nginx..."

        if command -v nginx &> /dev/null; then
            sudo nginx -s reload 2>/dev/null || nginx -s reload 2>/dev/null || true
            log OK "nginx recargado"
        fi
    else
        log WARN "nginx no está ejecutándose"
        log INFO "Inicia nginx para ver los cambios: sudo nginx"
    fi

    # Mostrar estadísticas
    local file_count
    file_count=$(find "${nginx_html_dir}" -type f 2>/dev/null | wc -l)
    log INFO "Archivos servidos: ${file_count}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN: Mostrar estado
# ═══════════════════════════════════════════════════════════════════════════════

show_status() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║              Estado de Nginx y Contenido Estático PRONTO             ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""

    echo "  Configuración actual:"
    echo "    NGINX_PREFIX:    ${NGINX_PREFIX:-no definido}"
    echo "    NGINX_HOST:      ${NGINX_HOST:-localhost}"
    echo "    NGINX_PORT:      ${NGINX_PORT:-9088}"
    echo "    NGINX_USER:      ${NGINX_USER:-root}"
    echo ""

    echo "  Contenido estático:"
    echo "    Directorio:      ${STATIC_CONTENT_DIR}"
    if [ -d "$STATIC_CONTENT_DIR" ]; then
        echo "    Archivos:        $(find "$STATIC_CONTENT_DIR" -type f 2>/dev/null | wc -l)"
        echo "    Directorios:     $(find "$STATIC_CONTENT_DIR" -type d 2>/dev/null | wc -l)"
        echo "    Tamaño:          $(du -sh "$STATIC_CONTENT_DIR" 2>/dev/null | cut -f1)"
    else
        echo "    ⚠️  Directorio no existe"
    fi
    echo ""

    echo "  Nginx:"
    if pgrep -x nginx > /dev/null 2>&1; then
        echo "    Estado:          ✅ Ejecutándose"

        local nginx_prefix="${NGINX_PREFIX:-}"
        if [ -z "$nginx_prefix" ]; then
            nginx_prefix=$(nginx -V 2>&1 | grep -oP '(?<=--prefix=)\S+' | head -1 || echo "desconocido")
        fi

        local nginx_html_dir="${nginx_prefix}/html"
        if [ -d "$nginx_html_dir" ]; then
            echo "    HTML Directory:  ${nginx_html_dir}"
            echo "    Archivos served: $(find "$nginx_html_dir" -type f 2>/dev/null | wc -l)"
        fi
    else
        echo "    Estado:          ⚠️  No está ejecutándose"
    fi

    echo ""

    # Probar conectividad
    local test_url="http://${NGINX_HOST:-localhost}:${NGINX_PORT:-9088}/"
    echo "  Conectividad:"
    echo "    URL de prueba:   ${test_url}"

    if command -v curl &> /dev/null; then
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" "${test_url}" 2>/dev/null || echo "error")
        echo "    Respuesta:       ${http_code}"
    fi

    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN: Probar nginx
# ═══════════════════════════════════════════════════════════════════════════════

test_nginx() {
    log STEP "Probando configuración de nginx..."

    local nginx_prefix="${NGINX_PREFIX:-}"

    if [ -z "$nginx_prefix" ]; then
        nginx_prefix=$(nginx -V 2>&1 | grep -oP '(?<=--prefix=)\S+' | head -1 || true)
    fi

    if [ -n "$nginx_prefix" ] && command -v nginx &> /dev/null; then
        log INFO "Ejecutando: nginx -t"
        nginx -t 2>&1 | while read -r line; do
            if echo "$line" | grep -qi "successful\|failed\|error"; then
                echo "$line"
            fi
        done
    else
        log WARN "nginx no está disponible para probar"
    fi

    # Probar URL
    local test_url="http://${NGINX_HOST:-localhost}:${NGINX_PORT:-9088}/"
    log INFO "Probando URL: ${test_url}"

    if command -v curl &> /dev/null; then
        local response
        response=$(curl -s -w "\n%{http_code}" "${test_url}" 2>/dev/null || echo "error")
        local http_code=$(echo "$response" | tail -1)
        local body=$(echo "$response" | head -n -1)

        if [ "$http_code" = "200" ]; then
            log OK "Servidor respondiendo: HTTP ${http_code}"
        elif [ "$http_code" = "000" ]; then
            log WARN "No se pudo conectar al servidor"
        else
            log WARN "Servidor respondiendo: HTTP ${http_code}"
        fi
    else
        log INFO "curl no disponible, omitiendo prueba de URL"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN: Inicializar y detectar nginx
# ═══════════════════════════════════════════════════════════════════════════════

init_nginx() {
    log STEP "Inicializando configuración de nginx..."

    # Detectar nginx
    local nginx_info
    nginx_info=$(detect_nginx)

    if echo "$nginx_info" | grep -q "NGINX_PREFIX="; then
        local nginx_prefix
        nginx_prefix=$(echo "$nginx_info" | grep "NGINX_PREFIX=" | cut -d= -f2)

        if [ -n "$nginx_prefix" ]; then
            # Actualizar general.env
            update_nginx_env "$nginx_prefix"

            log OK "Configuración de nginx inicializada"
            return 0
        fi
    fi

    log WARN "No se pudo detectar nginx automáticamente"
    log INFO "Configura las variables manualmente en .env:"
    log INFO "  NGINX_PREFIX=/ruta/a/nginx"
    log INFO "  NGINX_HOST=localhost"
    log INFO "  NGINX_PORT=9088"

    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    local action="${1:-status}"

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║          Gestión de Contenido Estático para Nginx PRONTO             ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""

    # Cargar variables de entorno actualizadas
    source "${CONFIG_FILE}" 2>/dev/null || true

    case "$action" in
        detect)
            detect_nginx
            ;;
        init)
            init_nginx
            ;;
        sync)
            sync_to_nginx
            ;;
        status)
            show_status
            ;;
        test)
            test_nginx
            ;;
        help|--help|-h)
            echo "Uso: $0 [comando]"
            echo ""
            echo "Comandos:"
            echo "  detect  - Detectar ubicación de nginx"
            echo "  init    - Detectar y guardar configuración en general.env"
            echo "  sync    - Sincronizar contenido estático a nginx"
            echo "  status  - Mostrar estado de nginx y contenido"
            echo "  test    - Probar configuración de nginx"
            echo "  help    - Mostrar esta ayuda"
            echo ""
            echo "Variables de entorno:"
            echo "  NGINX_PREFIX=/path/to/nginx   - Directorio root de nginx"
            echo "  NGINX_HOST=localhost          - Host de nginx"
            echo "  NGINX_PORT=9088               - Puerto de nginx"
            echo "  NGINX_USER=root               - Usuario para permisos"
            echo ""
            ;;
        *)
            log ERROR "Comando desconocido: ${action}"
            echo "Usa '$0 help' para ver la ayuda"
            exit 1
            ;;
    esac
}

main "$@"
