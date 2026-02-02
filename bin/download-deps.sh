#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${PROJECT_ROOT}/.." && pwd)"

echo ">> Descargando dependencias Python a local (build/wheels)..."
mkdir -p "${PROJECT_ROOT}/build/wheels"

# Check if pip is available
if ! command -v pip3 >/dev/null 2>&1;
then
    if ! command -v pip >/dev/null 2>&1;
    then
        echo "❌ No se encontró pip ni pip3. No se pueden descargar las dependencias."
        exit 1
    else
        PIP_CMD="pip"
    fi
else
    PIP_CMD="pip3"
fi

# Detectar arquitectura para descargar wheels correctos (arm64 vs x86_64)
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    # Apple Silicon / Linux ARM
    PLATFORM="manylinux2014_aarch64"
    echo "   - Detectado sistema ARM64. Descargando wheels para $PLATFORM..."
else
    # Intel/AMD64
    PLATFORM="manylinux2014_x86_64"
    echo "   - Detectado sistema x86_64. Descargando wheels para $PLATFORM..."
fi

# Usamos flags para asegurar compatibilidad con python:3.11-slim (Debian)
# Esto descarga wheels binarias si existen, o fuentes si no.
# Nota: Si falla en paquetes con extensiones C, se requerirá compilación en el contenedor.
REQ_ARGS=()
for req in \
  "${REPO_ROOT}/pronto-api/requirements.txt"; do
  if [ -f "${req}" ]; then
    REQ_ARGS+=("-r" "${req}")
  fi
done

"$PIP_CMD" download \
  --dest "${PROJECT_ROOT}/build/wheels" \
  --platform "$PLATFORM" \
  --python-version 3.11 \
  --implementation cp \
  --abi cp311 \
  --only-binary=:all: \
  "${REQ_ARGS[@]}" \
  gunicorn flask-cors flask-session requests==2.32.3 greenlet \
  --no-cache-dir || {
    echo "⚠️  Hubo un error descargando wheels binarias. Intentando descarga mixta (source + binary)..."
    "$PIP_CMD" download \
      --dest "${PROJECT_ROOT}/build/wheels" \
      "${REQ_ARGS[@]}" \
      gunicorn flask-cors flask-session requests==2.32.3 greenlet \
      --no-cache-dir
  }

echo "✅ Dependencias descargadas en build/wheels"
