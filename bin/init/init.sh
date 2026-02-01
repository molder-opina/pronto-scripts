#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

source "${SCRIPT_DIR}/_env_utils.sh"

NON_INTERACTIVE=false
AUTO_CONFIRM=false
DUMMY_DATA=false
SKIP_BUILD=false
SKIP_MIGRATIONS=false
ROLLBACK_MIGRATIONS=false
FORCE_ROLLBACK=false

GENERAL_ENV_SRC=""
SECRETS_ENV_SRC=""
BUSINESS_NAME=""
RESTAURANT_SLUG=""

SET_VALUES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --non-interactive)
      NON_INTERACTIVE=true; shift;;
    --yes)
      AUTO_CONFIRM=true; shift;;
    --dummy-data)
      DUMMY_DATA=true; shift;;
    --skip-build)
      SKIP_BUILD=true; shift;;
    --skip-migrations)
      SKIP_MIGRATIONS=true; shift;;
    --rollback-migrations)
      ROLLBACK_MIGRATIONS=true; shift;;
    --force-rollback)
      FORCE_ROLLBACK=true; shift;;
    --general-env)
      GENERAL_ENV_SRC="$2"; shift 2;;
    --secrets-env)
      SECRETS_ENV_SRC="$2"; shift 2;;
    --business-name)
      BUSINESS_NAME="$2"; shift 2;;
    --restaurant-slug)
      RESTAURANT_SLUG="$2"; shift 2;;
    --set)
      SET_VALUES+=("$2"); shift 2;;
    -h|--help)
      echo "Uso: bin/init/init.sh [opciones]"
      echo "  --business-name NAME"
      echo "  --restaurant-slug SLUG"
      echo "  --general-env PATH"
      echo "  --secrets-env PATH"
      echo "  --set KEY=VALUE (repetible)"
      echo "  --dummy-data"
      echo "  --skip-build"
      echo "  --skip-migrations"
      echo "  --rollback-migrations"
      echo "  --force-rollback"
      echo "  --non-interactive"
      echo "  --yes"
      exit 0;;
    *)
      echo "❌ Opción desconocida: $1" >&2
      exit 1;;
  esac
 done

if [ "$NON_INTERACTIVE" = false ]; then
  if [ -z "$BUSINESS_NAME" ]; then
    read -r -p "Nombre del negocio (RESTAURANT_NAME): " BUSINESS_NAME
  fi
  if [ -z "$RESTAURANT_SLUG" ]; then
    read -r -p "Slug del negocio (RESTAURANT_SLUG, opcional): " RESTAURANT_SLUG
  fi
  if [ "$DUMMY_DATA" = false ]; then
    read -r -p "¿Cargar datos dummy? (s/N): " reply
    if [[ "$reply" =~ ^[sS]$ ]]; then
      DUMMY_DATA=true
    fi
  fi
fi

BACKUP_DIR=$(resolve_backup_dir init-env)

bash "${SCRIPT_DIR}/01_backup_envs.sh" "$BACKUP_DIR"

APPLY_ARGS=("--yes")
if [ -n "$GENERAL_ENV_SRC" ]; then
  APPLY_ARGS+=("--general-env" "$GENERAL_ENV_SRC")
fi
if [ -n "$SECRETS_ENV_SRC" ]; then
  APPLY_ARGS+=("--secrets-env" "$SECRETS_ENV_SRC")
fi
if [ -n "$BUSINESS_NAME" ]; then
  APPLY_ARGS+=("--business-name" "$BUSINESS_NAME")
fi
if [ -n "$RESTAURANT_SLUG" ]; then
  APPLY_ARGS+=("--restaurant-slug" "$RESTAURANT_SLUG")
fi
for pair in "${SET_VALUES[@]}"; do
  APPLY_ARGS+=("--set" "$pair")
 done

if [ "$AUTO_CONFIRM" = true ]; then
  bash "${SCRIPT_DIR}/02_apply_envs.sh" "${APPLY_ARGS[@]}"
else
  bash "${SCRIPT_DIR}/02_apply_envs.sh" "${APPLY_ARGS[@]/--yes/}"
fi

SEED_ARGS=()
if [ "$DUMMY_DATA" = true ]; then
  SEED_ARGS+=("--dummy-data")
fi
if [ "$SKIP_MIGRATIONS" = true ]; then
  SEED_ARGS+=("--skip-migrations")
fi
if [ "$ROLLBACK_MIGRATIONS" = true ]; then
  SEED_ARGS+=("--rollback-migrations")
fi
if [ "$FORCE_ROLLBACK" = true ]; then
  SEED_ARGS+=("--force-rollback")
fi
bash "${SCRIPT_DIR}/03_seed_params.sh" "${SEED_ARGS[@]}"

if [ "$SKIP_BUILD" = false ]; then
  bash "${SCRIPT_DIR}/04_deploy.sh" "${SEED_ARGS[@]}"
fi

echo "✅ Inicialización completada. Backup: ${BACKUP_DIR}"
