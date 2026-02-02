#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Script: sync-shared-to-apps.sh
# PROPÓSITO: Este script ya NO es necesario con la nueva estructura.
# ═══════════════════════════════════════════════════════════════════════════════
#
# ANTIGUA (monorepo): shared/static/js/ → se sincronizaba a apps
# NUEVA (multi-repo): pronto_shared es un package pip instalado
#
# Los assets estáticos ahora viven en:
# - pronto-static/src/vue/shared/ → para Vue components
# - pronto-static/src/static_content/ → para assets (CSS, imágenes)
#
# Los módulos JS/TS se compilan independientemente en cada repo.
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

log INFO "Script deprecado: sync-shared-to-apps.sh"
log INFO "La sincronización ya no es necesaria con la estructura actual."
log INFO ""
log INFO "Estructura actual:"
log INFO "  - pronto_shared (Python): package en pronto-libs, instalado via pip"
log INFO "  - Vue components: en pronto-static/src/vue/shared/"
log INFO "  - Static assets: en pronto-static/src/static_content/"
log INFO ""
log INFO "Cada aplicación gestiona sus propios assets."

exit 0
