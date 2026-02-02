#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

ROLLBACK=false
MIGRATION_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rollback)
      ROLLBACK=true; shift;;
    --force-rollback)
      ROLLBACK=true; shift;;
    *)
      MIGRATION_FILE="$1"; shift;;
  esac
 done

if [ -z "$MIGRATION_FILE" ]; then
  echo "❌ Debes indicar la migración a aplicar" >&2
  exit 1
fi

if [ ! -f "$MIGRATION_FILE" ]; then
  echo "❌ Migración no encontrada: $MIGRATION_FILE" >&2
  exit 1
fi

# Load environment variables
if [ -f "${PROJECT_ROOT}/.env" ]; then
    set -a
    source "${PROJECT_ROOT}/.env"
    set +a
fi

DB_HOST="${SUPABASE_DB_HOST}"
DB_PORT="${SUPABASE_DB_PORT:-5432}"
DB_USER="${SUPABASE_DB_USER}"
DB_NAME="${SUPABASE_DB_NAME:-postgres}"
DB_PASSWORD="${SUPABASE_DB_PASSWORD}"

if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
  echo "❌ Error: Credenciales de base de datos no encontradas en el ambiente" >&2
  echo "Por favor asegúrate de que SUPABASE_DB_HOST, SUPABASE_DB_USER y SUPABASE_DB_PASSWORD están configurados" >&2
  exit 1
fi

if ! command -v psql &> /dev/null; then
  echo "❌ Error: comando psql no encontrado" >&2
  echo "Por favor instala las herramientas de cliente PostgreSQL:" >&2
  exit 1
fi

ACTION_LABEL="Aplicando"
if [ "$ROLLBACK" = true ]; then
  ACTION_LABEL="Revirtiendo"
fi

echo "🔄 ${ACTION_LABEL} migración ${MIGRATION_FILE} en Supabase PostgreSQL"

export PGPASSWORD="$DB_PASSWORD"
if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$MIGRATION_FILE"; then
  echo "✅ Migración aplicada exitosamente"
else
  echo "❌ Error al aplicar migración" >&2
  exit 1
fi

unset PGPASSWORD
