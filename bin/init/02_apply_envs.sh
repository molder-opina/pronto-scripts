#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

source "${SCRIPT_DIR}/_env_utils.sh"

GENERAL_ENV="${PROJECT_ROOT}/.env"

GENERAL_ENV_SRC=""
SECRETS_ENV_SRC=""
BUSINESS_NAME=""
RESTAURANT_SLUG=""
AUTO_CONFIRM=false

SET_VALUES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --yes)
      AUTO_CONFIRM=true; shift;;
    *)
      echo "❌ Opción desconocida: $1" >&2
      exit 1;;
  esac
 done

confirm_replace() {
  local label="$1"
  if [ "$AUTO_CONFIRM" = true ]; then
    return 0
  fi
  read -r -p "¿Reemplazar ${label}? (s/N): " reply
  [[ "${reply}" =~ ^[sS]$ ]]
}

if [ -n "$GENERAL_ENV_SRC" ]; then
  if confirm_replace ".env"; then
    replace_env_file "$GENERAL_ENV" "$GENERAL_ENV_SRC"
    echo "✅ .env actualizado desde $GENERAL_ENV_SRC"
  fi
fi

if [ -n "$BUSINESS_NAME" ]; then
  update_env_key "$GENERAL_ENV" "RESTAURANT_NAME" "$BUSINESS_NAME"
  echo "✅ RESTAURANT_NAME actualizado"
fi

if [ -n "$RESTAURANT_SLUG" ]; then
  update_env_key "$GENERAL_ENV" "RESTAURANT_SLUG" "$RESTAURANT_SLUG"
  echo "✅ RESTAURANT_SLUG actualizado"
fi

for pair in "${SET_VALUES[@]}"; do
  if [[ "$pair" != *"="* ]]; then
    echo "⚠️  Ignorando valor inválido: $pair" >&2
    continue
  fi
  key=${pair%%=*}
  value=${pair#*=}
  update_env_key "$GENERAL_ENV" "$key" "$value"
  echo "✅ ${key} actualizado"
 done
