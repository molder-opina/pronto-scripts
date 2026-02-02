#!/usr/bin/env bash
# bin/lib/build_helpers.sh
# Helper functions for building and preparing dependencies

run_frontend_builds() {
  local need_employees=0
  local need_clients=0
  for svc in "${SERVICES[@]}"; do
    case "$svc" in
      employee) need_employees=1 ;;
      client) need_clients=1 ;;
    esac
  done
  if [[ $need_employees -eq 0 && $need_clients -eq 0 ]]; then
    return
  fi
  if ! command -v npm > /dev/null 2>&1; then
    echo "⚠️ npm no está disponible; omitiendo build de bundles TypeScript."
    return
  fi
  if [[ $need_employees -eq 1 ]]; then
    echo ">> Generando bundle frontend para empleados (npm run build:employees)..."
    (cd "${PROJECT_ROOT}" && npm run build:employees)
  fi
  if [[ $need_clients -eq 1 ]]; then
    echo ">> Generando bundle frontend para clientes (npm run build:clients)..."
    (cd "${PROJECT_ROOT}" && npm run build:clients)
  fi
}

prepare_dependencies() {
  echo ">> Descargando dependencias Python a local (build/wheels)..."

  # Verificar si las dependencias ya están descargadas
  WHEELS_DIR="${PROJECT_ROOT}/build/wheels"
  mkdir -p "$WHEELS_DIR"

  # Contar wheels actuales
  CURRENT_WHEELS=$(find "$WHEELS_DIR" -name "*.whl" 2>/dev/null | wc -l | tr -d ' ')

  if [[ $CURRENT_WHEELS -gt 60 ]]; then
      echo "   ℹ️  Ya existen $CURRENT_WHEELS wheels descargadas en build/wheels/"
      echo "   ℹ️  Las dependencias se reutilizarán del cache local."
      echo "   ℹ️  Para forzar redescarga: rm -rf build/wheels/*"
      echo ""
      return 0
  fi

  echo "   ℹ️  Solo $CURRENT_WHEELS wheels encontradas. Descargando dependencias..."
  echo ""

  # Check if pip is available
  if ! command -v pip3 > /dev/null 2>&1; then
      if ! command -v pip > /dev/null 2>&1; then
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
  "$PIP_CMD" download \
    --dest "${PROJECT_ROOT}/build/wheels" \
    --platform "$PLATFORM" \
    --python-version 3.11 \
    --implementation cp \
    --abi cp311 \
    --only-binary=:all: \
    -r "${PROJECT_ROOT}/build/pronto_clients/requirements.txt" \
    -r "${PROJECT_ROOT}/build/pronto_employees/requirements.txt" \
    gunicorn flask-cors flask-session requests==2.32.3 greenlet \
    --no-cache-dir || {
      echo "⚠️  Hubo un error descargando wheels binarias. Intentando descarga mixta (source + binary)..."
      "$PIP_CMD" download \
        --dest "${PROJECT_ROOT}/build/wheels" \
        -r "${PROJECT_ROOT}/build/pronto_clients/requirements.txt" \
        -r "${PROJECT_ROOT}/build/pronto_employees/requirements.txt" \
        gunicorn flask-cors flask-session requests==2.32.3 greenlet \
        --no-cache-dir
    }

  # Mostrar resumen de descarga
  FINAL_WHEELS=$(find "$WHEELS_DIR" -name "*.whl" 2>/dev/null | wc -l | tr -d ' ')
  echo "   ✅ Descarga completada. $FINAL_WHEELS wheels disponibles en build/wheels/"
}
