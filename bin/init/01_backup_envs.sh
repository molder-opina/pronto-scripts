#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

source "${SCRIPT_DIR}/_env_utils.sh"

GENERAL_ENV="${PROJECT_ROOT}/config/general.env"
SECRETS_ENV="${PROJECT_ROOT}/config/secrets.env"

BACKUP_DIR=${1:-"$(resolve_backup_dir init-env)"}

echo "📦 Creando backups en: ${BACKUP_DIR}"
backup_file "$GENERAL_ENV" "$BACKUP_DIR"
backup_file "$SECRETS_ENV" "$BACKUP_DIR"
