#!/usr/bin/env bash
#
# PRONTO Full Project Audit
# Ejecuta auditorías especializadas por proyecto usando LLMs
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROMPTS_DIR="pronto-scripts/prompts/audits"
ERRORS_DIR="pronto-docs/errors"

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

PROJECTS=("pronto-api" "pronto-employees" "pronto-client" "pronto-static" "pronto-libs")

check_opencode() {
    if ! command -v opencode >/dev/null 2>&1; then
        log_error "opencode no está instalado. Por favor instálalo para ejecutar auditorías con LLM."
        exit 1
    fi
}

run_structures_audit() {
    local prompt_file="${PROMPTS_DIR}/structures_audit.md"
    local output_file="pronto-docs/audits/last_structures_audit.md"

    log_info "Iniciando auditoría de estructuras e integridad (DDL vs Modelos vs TS)..."
    
    # Esta auditoría se corre desde el root porque necesita acceso a múltiples subproyectos
    opencode run \
        --dir "${REPO_ROOT}" \
        --prompt-file "${REPO_ROOT}/${prompt_file}" \
        --message "Por favor, analiza la consistencia entre SQL (pronto-scripts/init/sql), Modelos (pronto-libs/src/pronto_shared/models.py) e Interfaces TS (pronto-static/src/vue/shared/types)." \
        --out "${REPO_ROOT}/${output_file}"

    if [ -f "${REPO_ROOT}/${output_file}" ]; then
        log_success "Auditoría de estructuras completada. Ver: ${output_file}"
    else
        log_error "Falló la auditoría de estructuras"
    fi
}

run_audit() {
    local project=$1
    local prompt_file="${PROMPTS_DIR}/${project#pronto-}_audit.md"
    local output_file="pronto-docs/audits/last_${project}_audit.md"

    mkdir -p "pronto-docs/audits"

    log_info "Iniciando auditoría para ${project}..."
    
    # Preparamos el contexto: lista de archivos y últimos cambios
    local changed_files=$(git diff --name-only HEAD~1..HEAD -- "${project}" || echo "ninguno")
    
    # Ejecutamos opencode
    # Pasamos el proyecto como directorio de trabajo para que el LLM pueda leer archivos
    opencode run 
        --dir "${REPO_ROOT}/${project}" 
        --prompt-file "${REPO_ROOT}/${prompt_file}" 
        --message "Archivos modificados recientemente: ${changed_files}. Por favor, realiza la auditoría completa sobre este folder." 
        --out "${REPO_ROOT}/${output_file}"

    if [ -f "${REPO_ROOT}/${output_file}" ]; then
        log_success "Auditoría de ${project} completada. Ver: ${output_file}"
    else
        log_error "Falló la auditoría de ${project}"
    fi
}

main() {
    check_opencode
    
    for project in "${PROJECTS[@]}"; do
        run_audit "${project}"
    done

    run_structures_audit

    log_success "Proceso de auditoría integral finalizado."
}

main "$@"
