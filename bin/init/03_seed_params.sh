#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

DUMMY_DATA=false
SKIP_MIGRATIONS=false
ROLLBACK_MIGRATIONS=false
FORCE_ROLLBACK=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dummy-data)
      DUMMY_DATA=true; shift;;
    --skip-migrations)
      SKIP_MIGRATIONS=true; shift;;
    --rollback-migrations)
      ROLLBACK_MIGRATIONS=true; shift;;
    --force-rollback)
      FORCE_ROLLBACK=true; shift;;
    *)
      echo "❌ Opción desconocida: $1" >&2
      exit 1;;
  esac
 done

if [ -f "${PROJECT_ROOT}/config/general.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "${PROJECT_ROOT}/config/general.env"
  set +a
fi

if [ -f "${PROJECT_ROOT}/config/secrets.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "${PROJECT_ROOT}/config/secrets.env"
  set +a
fi

if [ "$ROLLBACK_MIGRATIONS" = true ]; then
  if [ -t 0 ] && [ "$FORCE_ROLLBACK" = false ]; then
    read -r -p "⚠️  Confirmar rollback de migraciones? (s/N): " reply
    if [[ ! "$reply" =~ ^[sS]$ ]]; then
      echo "Rollback cancelado."
      exit 1
    fi
  fi
  bash "${SCRIPT_DIR}/05_apply_migrations.sh" --rollback \
    "${PROJECT_ROOT}/src/shared/migrations/009_add_pronto_secrets_rollback.sql"
elif [ "$SKIP_MIGRATIONS" = false ]; then
  bash "${SCRIPT_DIR}/05_apply_migrations.sh" \
    "${PROJECT_ROOT}/src/shared/migrations/009_add_pronto_secrets.sql"
fi

if [ "$DUMMY_DATA" = true ]; then
  echo "📦 Cargando datos dummy (seed)..."
  export LOAD_SEED_DATA=true
  python3 "${PROJECT_ROOT}/src/shared/services/seed.py"
fi

echo "🔁 Sincronizando config/secrets con base de datos..."
PYTHONPATH="${PROJECT_ROOT}/build" python3 - <<'PY'
from shared.config import load_config
from shared.db import init_engine, init_db
from shared.models import Base
from shared.services.business_config_service import sync_env_config_to_db
from shared.services.secret_service import sync_env_secrets_to_db

config = load_config("pronto-init")
init_engine(config)
init_db(Base.metadata)

sync_env_config_to_db()
sync_env_secrets_to_db()
PY
