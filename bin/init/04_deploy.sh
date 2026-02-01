#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

SEED_FLAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dummy-data)
      SEED_FLAG="--seed"; shift;;
    *)
      echo "❌ Opción desconocida: $1" >&2
      exit 1;;
  esac
 done

echo "🚀 Compilando y desplegando..."
if [ -n "$SEED_FLAG" ]; then
  bash "${PROJECT_ROOT}/bin/rebuild.sh" "$SEED_FLAG"
else
  bash "${PROJECT_ROOT}/bin/rebuild.sh"
fi
