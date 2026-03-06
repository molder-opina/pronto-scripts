#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PY_SCRIPT="${SCRIPT_DIR}/python/generate_menu_home_artifact.py"

PLACEMENT="home_client"
OUTPUT_PATH="${PROJECT_ROOT}/pronto-static/src/static_content/assets/pronto/menu/home-published.json"
BUILD_CMD=""
DEPLOY_CMD=""
PUBLISH=true
PREVIEW=false

usage() {
  cat <<EOF
Uso: $(basename "$0") [opciones]

Publica el snapshot de home menu de forma atómica y genera artefacto estático.

Opciones:
  --placement <value>     Placement objetivo (default: home_client)
  --output <path>         Archivo de salida del artefacto JSON
  --build-cmd "<cmd>"     Comando de build a ejecutar antes de promover publish
  --deploy-cmd "<cmd>"    Comando de deploy a ejecutar antes de promover publish
  --no-publish            Solo genera artefacto desde snapshot ya publicado
  --preview               Genera artefacto desde preview draft (no publicado)
  -h, --help              Muestra esta ayuda

Ejemplos:
  $(basename "$0")
  $(basename "$0") --build-cmd "./pronto-scripts/bin/rebuild.sh client"
  $(basename "$0") --no-publish
  $(basename "$0") --preview
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --placement)
      PLACEMENT="$2"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --build-cmd)
      BUILD_CMD="$2"
      shift 2
      ;;
    --deploy-cmd)
      DEPLOY_CMD="$2"
      shift 2
      ;;
    --no-publish)
      PUBLISH=false
      shift
      ;;
    --preview)
      PREVIEW=true
      PUBLISH=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Argumento no reconocido: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -x "$PY_SCRIPT" ]]; then
  echo "Script no ejecutable: $PY_SCRIPT" >&2
  exit 1
fi

if [[ "$PREVIEW" == "true" ]]; then
  python3 "$PY_SCRIPT" \
    --placement "$PLACEMENT" \
    --output "$OUTPUT_PATH" \
    --preview
  exit 0
fi

if [[ "$PUBLISH" == "true" ]]; then
  cmd=(python3 "$PY_SCRIPT" --placement "$PLACEMENT" --output "$OUTPUT_PATH" --publish)
  if [[ -n "$BUILD_CMD" ]]; then
    cmd+=(--build-cmd "$BUILD_CMD")
  fi
  if [[ -n "$DEPLOY_CMD" ]]; then
    cmd+=(--deploy-cmd "$DEPLOY_CMD")
  fi
  "${cmd[@]}"
  exit 0
fi

python3 "$PY_SCRIPT" \
  --placement "$PLACEMENT" \
  --output "$OUTPUT_PATH"
