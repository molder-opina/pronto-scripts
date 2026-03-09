#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

source "${SCRIPT_DIR}/env-utils.sh"

GENERAL_ENV="${PROJECT_ROOT}/.env"

BACKUP_DIR=${1:-"$(resolve_backup_dir init-env)"}

echo "📦 Creando backups en: ${BACKUP_DIR}"
backup_file "$GENERAL_ENV" "$BACKUP_DIR"
