#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Script: sync-shared-to-apps.sh
# Propósito: Sincronizar contenido de shared static a las aplicaciones
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    local level="$1"
    local message="$2"
    local color
    case "$level" in
        INFO)    color="${GREEN}" ;;
        WARN)    color="${YELLOW}" ;;
        ERROR)   color="${RED}" ;;
        *)       color="${NC}" ;;
    esac
    echo -e "${color}[${level}]${NC} ${message}"
}

log INFO "Sincronizando shared static → employees_app..."

# JS compilados
log INFO "Copiando JS compilados..."
cp -f "${ROOT_DIR}/src/shared/static/js/dist/employees/"*.js \
    "${ROOT_DIR}/src/employees_app/static/js/dist/employees/" 2>/dev/null || true

# Chunks
cp -rf "${ROOT_DIR}/src/shared/static/js/dist/employees/chunks/"* \
    "${ROOT_DIR}/src/employees_app/static/js/dist/employees/chunks/" 2>/dev/null || true

# Assets
cp -rf "${ROOT_DIR}/src/shared/static/js/dist/employees/assets/"* \
    "${ROOT_DIR}/src/employees_app/static/js/dist/employees/assets/" 2>/dev/null || true

# CSS modules (vanilla JS)
log INFO "Copiando módulos JS..."
for file in keyboard-shortcuts.js pagination.js realtime.js loading.js \
    notifications.js feedback_dashboard.js business_config.js roles_management.js \
    shortcuts_admin.js employees_manager_vanilla.js roles_manager_vanilla.js; do
    if [ -f "${ROOT_DIR}/src/shared/static/js/${file}" ]; then
        cp -f "${ROOT_DIR}/src/shared/static/js/${file}" \
            "${ROOT_DIR}/src/employees_app/static/js/${file}" 2>/dev/null || true
    fi
done

# CSS
log INFO "Copiando CSS..."
for file in dashboard.css reports.css styles.css tokens.css waiter-pos-modern.css waiter.css; do
    if [ -f "${ROOT_DIR}/src/shared/static/css/${file}" ]; then
        cp -f "${ROOT_DIR}/src/shared/static/css/${file}" \
            "${ROOT_DIR}/src/employees_app/static/css/${file}" 2>/dev/null || true
    fi
done

# Components CSS
log INFO "Copiando CSS de componentes..."
cp -rf "${ROOT_DIR}/src/shared/static/css/components/"* \
    "${ROOT_DIR}/src/employees_app/static/css/components/" 2>/dev/null || true

# notifications.css
if [ -f "${ROOT_DIR}/src/static_content/assets/css/notifications.css" ]; then
    cp -f "${ROOT_DIR}/src/static_content/assets/css/notifications.css" \
        "${ROOT_DIR}/src/employees_app/static/css/notifications.css" 2>/dev/null || true
fi

log INFO "Sincronización completada"
log INFO "Archivos en employees/dist/employees: $(ls "${ROOT_DIR}/src/employees_app/static/js/dist/employees/"*.js 2>/dev/null | wc -l)"
