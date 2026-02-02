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

if [ -f "${PROJECT_ROOT}/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "${PROJECT_ROOT}/.env"
  set +a
fi

# Find migrations directory
MIGRATIONS_DIR=""
for path in \
    "${PROJECT_ROOT}/../pronto-libs/src/pronto_shared/migrations" \
    "${PROJECT_ROOT}/../pronto-libs/build/lib/pronto_shared/migrations" \
    "/opt/pronto/lib/pronto_shared/migrations"; do
    if [ -d "$path" ]; then
        MIGRATIONS_DIR="$path"
        break
    fi
done

if [ "$ROLLBACK_MIGRATIONS" = true ]; then
  if [ -t 0 ] && [ "$FORCE_ROLLBACK" = false ]; then
    read -r -p "⚠️  Confirmar rollback de migraciones? (s/N): " reply
    if [[ ! "$reply" =~ ^[sS]$ ]]; then
      echo "Rollback cancelado."
      exit 1
    fi
  fi
  if [ -n "$MIGRATIONS_DIR" ]; then
    bash "${SCRIPT_DIR}/05_apply_migrations.sh" --rollback \
      "${MIGRATIONS_DIR}/009_add_pronto_secrets_rollback.sql"
  else
    echo "❌ No se encontró el directorio de migraciones."
    echo "   Asegúrate de que pronto_shared esté instalado:"
    echo "   cd ../pronto-libs && pip install -e ."
    exit 1
  fi
elif [ "$SKIP_MIGRATIONS" = false ]; then
  if [ -n "$MIGRATIONS_DIR" ]; then
    bash "${SCRIPT_DIR}/05_apply_migrations.sh" \
      "${MIGRATIONS_DIR}/009_add_pronto_secrets.sql"
  else
    echo "❌ No se encontró el directorio de migraciones."
    echo "   Asegúrate de que pronto_shared esté instalado:"
    echo "   cd ../pronto-libs && pip install -e ."
    exit 1
  fi
fi

if [ "$DUMMY_DATA" = true ]; then
  echo "📦 Cargando datos dummy (seed)..."
  export LOAD_SEED_DATA=true
  # Try to find seed.py
  SEED_PATH=""
  for path in \
      "${PROJECT_ROOT}/../pronto-libs/src/pronto_shared/services/seed.py" \
      "${PROJECT_ROOT}/../pronto-libs/build/lib/pronto_shared/services/seed.py" \
      "/opt/pronto/lib/pronto_shared/services/seed.py"; do
      if [ -f "$path" ]; then
          SEED_PATH="$path"
          break
      fi
  done
  
  if [ -n "$SEED_PATH" ]; then
    PYTHONPATH="$(dirname "$SEED_PATH"):${PYTHONPATH:-}" python3 "$SEED_PATH"
  else
    echo "❌ No se encontró seed.py"
  fi
fi

echo "🔁 Sincronizando config/secrets con base de datos..."

# Check if pronto_shared is available
if python3 -c "import pronto_shared" 2>/dev/null; then
  python3 - <<'PY'
from pronto_shared.config import load_config
from pronto_shared.db import init_engine, init_db
from pronto_shared.models import Base
from pronto_shared.services.business_config_service import sync_env_config_to_db
from pronto_shared.services.secret_service import sync_env_secrets_to_db

config = load_config("pronto-init")
init_engine(config)
init_db(Base.metadata)

sync_env_config_to_db()
sync_env_secrets_to_db()
print("✅ Configuración sincronizada correctamente.")
PY
else
  echo "❌ pronto_shared no está disponible."
  echo "   Instálalo primero:"
  echo "   cd ../pronto-libs && pip install -e ."
  exit 1
fi
