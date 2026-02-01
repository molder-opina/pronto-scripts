#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Script: static-host-detector.sh
# Propósito: Detectar y configurar la URL del servidor de contenido estático
# Entornos:
#   - macOS con pod: Usa http://localhost:9088 (pod static service)
#   - Linux con nginx: Usa http://localhost:9088 (nginx local)
#   - Docker: Usa http://static:80 (servicio interno Docker)
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/general.env"

# Colores para输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes con formato
log() {
    local level="$1"
    local message="$2"
    local color

    case "$level" in
        INFO)    color="${BLUE}" ;;
        OK)      color="${GREEN}" ;;
        WARN)    color="${YELLOW}" ;;
        ERROR)   color="${RED}" ;;
        *)       color="${NC}" ;;
    esac

    echo -e "${color}[${level}]${NC} ${message}"
}

# Función para detectar el sistema operativo
detect_os() {
    local os
    os="$(uname -s)"

    case "$os" in
        Darwin)
            echo "macOS"
            ;;
        Linux)
            echo "Linux"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "Windows"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# Función para verificar si pod está ejecutándose (macOS)
check_pod_status() {
    if command -v pod &> /dev/null; then
        if pod ps &> /dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Función para verificar si nginx está configurado y ejecutándose (Linux)
check_nginx_status() {
    # Verificar si nginx está instalado
    if ! command -v nginx &> /dev/null; then
        log WARN "nginx no está instalado"
        return 1
    fi

    # Verificar si nginx está ejecutándose
    if pgrep -x nginx > /dev/null 2>&1; then
        return 0
    fi

    # Verificar si hay una configuración de nginx para el puerto 9088
    if nginx -t 2>/dev/null | grep -q "9088"; then
        log INFO "nginx configurado para puerto 9088 pero no está ejecutándose"
        return 1
    fi

    return 1
}

# Función para verificar si el contenedor static de Docker está ejecutándose
check_docker_static() {
    if command -v docker &> /dev/null; then
        if docker ps --format '{{.Names}}' | grep -q "static"; then
            return 0
        fi
    fi
    return 1
}

# Función para verificar si el puerto 9088 está abierto
check_port_9088() {
    local os
    os="$(detect_os)"

    if [ "$os" = "Darwin" ] || [ "$os" = "Linux" ]; then
        if command -v nc &> /dev/null; then
            nc -z localhost 9088 2>/dev/null && return 0
        elif command -v curl &> /dev/null; then
            curl -s -o /dev/null -w '%{http_code}' http://localhost:9088/ | grep -qE "200|301|302" && return 0
        fi
    fi
    return 1
}

# Función para generar la URL del servidor estático (silenciosa)
generate_static_url() {
    local os
    local use_pod_static

    os="$(detect_os)"
    use_pod_static="${USE_POD_STATIC:-false}"

    case "$os" in
        macOS)
            # En macOS, verificar si pod está activo
            if [ "$use_pod_static" = "true" ] || check_pod_status; then
                echo "http://localhost:9088"
            else
                echo "http://localhost:9088"
            fi
            ;;
        Linux)
            # En Linux, verificar nginx
            if check_nginx_status; then
                echo "http://localhost:9088"
            elif check_port_9088; then
                echo "http://localhost:9088"
            elif check_docker_static; then
                echo "http://static:80"
            else
                echo "http://localhost:9088"
            fi
            ;;
        *)
            echo "http://localhost:9088"
            ;;
    esac
}

# Función para actualizar el archivo de configuración
update_config_file() {
    local static_url="$1"
    local temp_file

    if [ ! -f "$CONFIG_FILE" ]; then
        log ERROR "Archivo de configuración no encontrado: ${CONFIG_FILE}"
        return 1
    fi

    temp_file=$(mktemp)

    # Crear backup del archivo original
    cp "${CONFIG_FILE}" "${CONFIG_FILE}.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

    # Actualizar o agregar la línea PRONTO_STATIC_CONTAINER_HOST
    if grep -q "^PRONTO_STATIC_CONTAINER_HOST=" "$CONFIG_FILE"; then
        sed "s|^PRONTO_STATIC_CONTAINER_HOST=.*|PRONTO_STATIC_CONTAINER_HOST=${static_url}|" "$CONFIG_FILE" > "$temp_file"
    else
        cp "$CONFIG_FILE" "$temp_file"
        echo "" >> "$temp_file"
        echo "# URL del servidor de contenido estático para el navegador/host" >> "$temp_file"
        echo "PRONTO_STATIC_CONTAINER_HOST=${static_url}" >> "$temp_file"
    fi

    mv "$temp_file" "$CONFIG_FILE"
    log OK "Archivo de configuración actualizado: ${CONFIG_FILE}"
}

# Función para exportar variables de entorno (silenciosa)
export_env_vars() {
    local static_url
    static_url=$(generate_static_url)

    export PRONTO_STATIC_CONTAINER_HOST="${static_url}"
}

# Función principal
main() {
    local action="${1:-detect}"
    local static_url

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║          Detección de Servidor de Contenido Estático PRONTO          ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""

    case "$action" in
        detect)
            static_url=$(generate_static_url)
            echo ""
            log INFO "URL del servidor estático: ${static_url}"
            echo ""
            ;;
        export)
            static_url=$(generate_static_url)
            export_env_vars "$static_url"
            echo ""
            ;;
        update-config)
            static_url=$(generate_static_url)
            update_config_file "$static_url"
            echo ""
            ;;
        status)
            echo "Estado del servidor de contenido estático:"
            echo ""
            echo "  Sistema operativo: $(detect_os)"
            echo "  USE_POD_STATIC: ${USE_POD_STATIC:-no definido}"
            echo "  Pod ejecutándose: $(check_pod_status && echo 'Sí' || echo 'No')"
            echo "  Nginx ejecutándose: $(check_nginx_status && echo 'Sí' || echo 'No')"
            echo "  Puerto 9088 abierto: $(check_port_9088 && echo 'Sí' || echo 'No')"
            echo ""
            static_url=$(generate_static_url)
            log INFO "URL sugerida: ${static_url}"
            echo ""
            ;;
        help|--help|-h)
            echo "Uso: $0 [comando]"
            echo ""
            echo "Comandos:"
            echo "  detect        - Solo detectar y mostrar la URL sugerida"
            echo "  export        - Detectar y exportar variables de entorno"
            echo "  update-config - Detectar y actualizar config/general.env"
            echo "  status        - Mostrar estado de servicios relacionados"
            echo "  help          - Mostrar esta ayuda"
            echo ""
            echo "Variables de entorno:"
            echo "  USE_POD_STATIC=true  - Forzar uso de pod static (macOS)"
            echo "  USE_POD_STATIC=false - No usar pod static"
            echo ""
            ;;
        *)
            log ERROR "Comando desconocido: ${action}"
            echo "Usa '$0 help' para ver la ayuda"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"
