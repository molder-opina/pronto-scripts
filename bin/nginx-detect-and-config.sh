#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Script: nginx-detect-and-config.sh
# Propósito: Detectar nginx y configurar variables de entorno en general.env
# Uso:
#   ./nginx-detect-and-config.sh          - Detectar y configurar (modo interactivo)
#   ./nginx-detect-and-config.sh --force  - Forzar reconfiguración
#   ./nginx-detect-and-config.sh --docker - Configurar para Docker (static:80)
#   ./nginx-detect-and-config.sh --local  - Configurar para nginx local (localhost:9088)
#   ./nginx-detect-and-config.sh --pod    - Configurar para pod (localhost:9088)
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
CONFIG_FILE="${ROOT_DIR}/.env"

# ═══════════════════════════════════════════════════════════════════════════════
# Configuración
# ═══════════════════════════════════════════════════════════════════════════════

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
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
# FUNCIÓN: Detectar tipo de entorno
# ═══════════════════════════════════════════════════════════════════════════════

detect_environment() {
    local os
    local has_docker
    local has_pod
    local has_nginx

    os="$(uname -s)"
    has_docker=false
    has_pod=false
    has_nginx=false

    # Detectar Docker
    if command -v docker &> /dev/null; then
        if docker ps &> /dev/null 2>&1; then
            has_docker=true
        fi
    fi

    # Detectar Pod (macOS)
    if command -v pod &> /dev/null; then
        if pod ps &> /dev/null 2>&1; then
            has_pod=true
        fi
    fi

    # Detectar nginx local
    if command -v nginx &> /dev/null; then
        has_nginx=true
    elif pgrep -x nginx > /dev/null 2>&1; then
        has_nginx=true
    fi

    echo "{
        \"os\": \"${os}\",
        \"has_docker\": ${has_docker},
        \"has_pod\": ${has_pod},
        \"has_nginx\": ${has_nginx}
    }"
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN: Detectar ubicación de nginx
# ═══════════════════════════════════════════════════════════════════════════════

detect_nginx_location() {
    local mode="${1:-auto}"

    log STEP "Detectando ubicación de nginx (modo: ${mode})..."

    local nginx_prefix=""
    local nginx_host=""
    local nginx_port=""

    case "$mode" in
        docker)
            # Modo Docker: usar servicio interno static
            nginx_host="static"
            nginx_port="80"
            nginx_prefix=""
            log INFO "Modo Docker: nginx interno (static:80)"
            ;;
        pod)
            # Modo Pod: usar localhost:9088
            nginx_host="localhost"
            nginx_port="9088"
            nginx_prefix=""
            log INFO "Modo Pod: http://localhost:9088"
            ;;
        local)
            # Modo Nginx local
            nginx_host="localhost"
            nginx_port="9088"

            # Intentar detectar prefix
            if command -v nginx &> /dev/null; then
                nginx_prefix=$(nginx -V 2>&1 | grep -oP '(?<=--prefix=)\S+' | head -1 || true)
            fi

            if [ -z "$nginx_prefix" ]; then
                # Buscar en ubicaciones comunes
                local common_prefixes=(
                    "/usr/local/nginx"
                    "/etc/nginx"
                    "/opt/homebrew/nginx"
                    "/usr/local/opt/nginx"
                )

                for prefix in "${common_prefixes[@]}"; do
                    if [ -d "${prefix}" ] && [ -f "${prefix}/conf/nginx.conf" ]; then
                        nginx_prefix="$prefix"
                        break
                    fi
                done
            fi

            log INFO "Modo Local: http://${nginx_host}:${nginx_port}"
            if [ -n "$nginx_prefix" ]; then
                log INFO "Nginx prefix: ${nginx_prefix}"
            fi
            ;;
        auto|*)
            # Detección automática según entorno
            local env_info
            env_info=$(detect_environment)
            local os
            local has_docker
            local has_pod
            local has_nginx

            os=$(echo "$env_info" | grep -o '"os": "[^"]*"' | cut -d'"' -f4)
            has_docker=$(echo "$env_info" | grep -o '"has_docker": [^,]*' | cut -d' ' -f2)
            has_pod=$(echo "$env_info" | grep -o '"has_pod": [^,]*' | cut -d' ' -f2)
            has_nginx=$(echo "$env_info" | grep -o '"has_nginx": [^,]*' | cut -d' ' -f2)

            log INFO "Sistema operativo: ${os}"
            log INFO "Docker disponible: ${has_docker}"
            log INFO "Pod disponible: ${has_pod}"
            log INFO "Nginx local: ${has_nginx}"

            case "$os" in
                Darwin)
                    # macOS: prefer pod o nginx local
                    if [ "$has_pod" = "true" ]; then
                        nginx_host="localhost"
                        nginx_port="9088"
                        nginx_prefix=""
                        log INFO "Detectado pod en macOS: http://localhost:9088"
                    elif [ "$has_nginx" = "true" ]; then
                        nginx_host="localhost"
                        nginx_port="9088"
                        nginx_prefix=$(nginx -V 2>&1 | grep -oP '(?<=--prefix=)\S+' | head -1 || true)
                        log INFO "Detectado nginx local: http://localhost:9088"
                    else
                        nginx_host="localhost"
                        nginx_port="9088"
                        log WARN "No se detectó pod ni nginx en macOS"
                        log INFO "Usando valores por defecto: http://localhost:9088"
                    fi
                    ;;
                Linux)
                    # Linux: prefer nginx local
                    if [ "$has_nginx" = "true" ]; then
                        nginx_host="localhost"
                        nginx_port="9088"
                        nginx_prefix=$(nginx -V 2>&1 | grep -oP '(?<=--prefix=)\S+' | head -1 || true)
                        log INFO "Detectado nginx en Linux: http://localhost:9088"
                    elif [ "$has_docker" = "true" ]; then
                        nginx_host="static"
                        nginx_port="80"
                        nginx_prefix=""
                        log INFO "Detectado Docker en Linux: http://static:80"
                    else
                        nginx_host="localhost"
                        nginx_port="9088"
                        log WARN "No se detectó nginx ni Docker en Linux"
                        log INFO "Usando valores por defecto: http://localhost:9088"
                    fi
                    ;;
                *)
                    # Otros sistemas: usar valores por defecto
                    nginx_host="localhost"
                    nginx_port="9088"
                    log WARN "Sistema no reconocido, usando valores por defecto"
                    ;;
            esac
            ;;
    esac

    # Retornar configuración detectada
    cat <<EOF
NGINX_HOST=${nginx_host}
NGINX_PORT=${nginx_port}
NGINX_PREFIX=${nginx_prefix:-}
EOF
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN: Actualizar general.env
# ═══════════════════════════════════════════════════════════════════════════════

update_config() {
    local mode="$1"
    local force="${2:-false}"

    log STEP "Actualizando configuración para modo: ${mode}"

    # Crear backup si no existe
    if [ ! -f "${CONFIG_FILE}.backup" ]; then
        cp "${CONFIG_FILE}" "${CONFIG_FILE}.backup"
        log INFO "Backup creado: ${CONFIG_FILE}.backup"
    fi

    # Detectar configuración
    local config
    config=$(detect_nginx_location "$mode")

    local nginx_host
    local nginx_port
    local nginx_prefix

    nginx_host=$(echo "$config" | grep "NGINX_HOST=" | cut -d= -f2)
    nginx_port=$(echo "$config" | grep "NGINX_PORT=" | cut -d= -f2)
    nginx_prefix=$(echo "$config" | grep "NGINX_PREFIX=" | cut -d= -f2)

    # Actualizar archivo de configuración
    local temp_file
    temp_file=$(mktemp)

    # Eliminar variables nginx existentes
    while IFS= read -r line; do
        if [[ "$line" =~ ^NGINX_ ]]; then
            continue
        fi
        echo "$line"
    done < "$CONFIG_FILE" > "$temp_file"

    # Agregar nuevas variables nginx al final
    cat >> "$temp_file" <<EOF

# Nginx Configuration (detectado automáticamente)
# Modo: ${mode}
NGINX_HOST=${nginx_host}
NGINX_PORT=${nginx_port}
NGINX_PREFIX=${nginx_prefix:-}
EOF

    mv "$temp_file" "$CONFIG_FILE"

    log OK "Configuración actualizada en: ${CONFIG_FILE}"
    log INFO "NGINX_HOST=${nginx_host}"
    log INFO "NGINX_PORT=${nginx_port}"
    if [ -n "$nginx_prefix" ]; then
        log INFO "NGINX_PREFIX=${nginx_prefix}"
    fi

    # Exportar variables para uso actual
    export NGINX_HOST="${nginx_host}"
    export NGINX_PORT="${nginx_port}"
    export NGINX_PREFIX="${nginx_prefix:-}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN: Mostrar ayuda
# ═══════════════════════════════════════════════════════════════════════════════

show_help() {
    cat <<EOF
${BOLD}Nginx Detect and Config${NC}

${BOLD}Uso:${NC}
  $(basename "$0") [opciones]

${BOLD}Opciones:${NC}
  --auto   Detectar automáticamente el entorno (por defecto)
  --force  Forzar reconfiguración incluso si ya existe
  --docker Configurar para Docker (http://static:80)
  --local  Configurar para nginx local (http://localhost:9088)
  --pod    Configurar para pod (http://localhost:9088)
  --help   Mostrar esta ayuda

${BOLD}Ejemplos:${NC}
  $(basename "$0")                    # Detección automática
  $(basename "$0") --docker           # Usar servicio static de Docker
  $(basename "$0") --local            # Usar nginx local
  $(basename "$0") --pod              # Usar pod (macOS)
  $(basename "$0") --force --local    # Forzar reconfiguración local

${BOLD}Entornos soportados:${NC}
  macOS con Pod    → http://localhost:9088
  macOS con Nginx  → http://localhost:9088
  Linux con Nginx  → http://localhost:9088
  Linux con Docker → http://static:80

${BOLD}Variables generadas en .env:${NC}
  NGINX_HOST       - Host del servidor nginx
  NGINX_PORT       - Puerto del servidor nginx
  NGINX_PREFIX     - Directorio root de nginx (opcional)

EOF
}

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIÓN PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    local mode="auto"
    local force=false

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║       Detección y Configuración de Nginx para PRONTO                 ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""

    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --auto)
                mode="auto"
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --docker)
                mode="docker"
                shift
                ;;
            --local)
                mode="local"
                shift
                ;;
            --pod)
                mode="pod"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log ERROR "Opción desconocida: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Verificar si ya existe configuración
    if [ "$force" = false ]; then
        if grep -q "^NGINX_HOST=" "$CONFIG_FILE" 2>/dev/null; then
            local existing_host
            existing_host=$(grep "^NGINX_HOST=" "$CONFIG_FILE" | cut -d= -f2)
            log INFO "Configuración de nginx ya existe: NGINX_HOST=${existing_host}"
            log INFO "Usa --force para reconfigurar"

            # Mostrar configuración actual
            echo ""
            echo "  Configuración actual:"
            grep "^NGINX_" "$CONFIG_FILE" 2>/dev/null | while read -r line; do
                echo "    ${line}"
            done
            echo ""

            read -p "¿Deseas reconfigurar? (s/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                log INFO "Manteniendo configuración actual"
                exit 0
            fi
        fi
    fi

    # Ejecutar detección y configuración
    update_config "$mode" "$force"

    echo ""
    log OK "Configuración completada"
    log INFO "Para usar en la sesión actual:"
    echo "    source ${CONFIG_FILE}"
    echo ""

    # Probar conectividad
    local test_url="http://${NGINX_HOST:-localhost}:${NGINX_PORT:-9088}/"
    log INFO "Probando conectividad: ${test_url}"

    if command -v curl &> /dev/null; then
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" "$test_url" 2>/dev/null || echo "error")

        if [ "$http_code" = "200" ]; then
            log OK "Servidor respondiendo: HTTP ${http_code}"
        elif [ "$http_code" = "000" ]; then
            log WARN "No se pudo conectar al servidor"
            log INFO "Verifica que el servidor esté ejecutándose"
        else
            log INFO "Servidor respondiendo: HTTP ${http_code}"
        fi
    fi
}

main "$@"
