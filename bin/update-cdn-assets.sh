#!/usr/bin/env bash
set -euo pipefail

# Descarga versiones locales de dependencias que antes cargaban desde CDN.
# Por defecto usa las versiones que ya teníamos en producción; puedes sobreescribirlas con variables de entorno.
SOCKET_IO_VERSION="${SOCKET_IO_VERSION:-4.5.4}"
CHART_JS_VERSION="${CHART_JS_VERSION:-4.4.0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
ASSETS_DIR="${REPO_ROOT}/pronto-static/src/static_content/assets/lib"

mkdir -p "${ASSETS_DIR}"

echo "Descargando socket.io v${SOCKET_IO_VERSION}..."
curl -sSL "https://cdn.socket.io/${SOCKET_IO_VERSION}/socket.io.min.js" \
  -o "${ASSETS_DIR}/socket.io.min.js"

echo "Descargando Chart.js v${CHART_JS_VERSION}..."
curl -sSL "https://cdn.jsdelivr.net/npm/chart.js@${CHART_JS_VERSION}/dist/chart.umd.min.js" \
  -o "${ASSETS_DIR}/chart.umd.min.js"

echo "Listo. Archivos guardados en ${ASSETS_DIR}"
