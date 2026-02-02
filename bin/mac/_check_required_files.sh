#!/usr/bin/env bash
# bin/mac/_check_required_files.sh - Helper para verificar archivos requeridos

check_required_files() {
    local required_files=(
        "${PROJECT_ROOT}/.env"
        "${PROJECT_ROOT}/docker-compose.yml"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "❌ Error: Archivo requerido no encontrado: $file"
            exit 1
        fi
    done
}
