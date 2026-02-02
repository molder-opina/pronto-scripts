#!/usr/bin/env bash
set -euo pipefail

# Script para limpiar sesiones antes del redeploy
# Uso: bin/cleanup-old-sessions.sh [--all]
#   --all: Limpia TODAS las sesiones (incluyendo abiertas)
#   Sin opciones: Solo limpia sesiones cerradas (closed, paid, cancelled, billed)

# Load environment variables if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"
if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=../.env
  source "${ENV_FILE}"
  set +a
fi

# Parse arguments
CLEAN_ALL=false
if [[ "$*" == *"--all"* ]]; then
  CLEAN_ALL=true
fi

EMPLOYEE_API_BASE="${EMPLOYEE_API_BASE_URL:-http://localhost:${EMPLOYEE_APP_HOST_PORT:-6081}}"
if [[ "$EMPLOYEE_API_BASE" == */api ]]; then
  API_BASE="${EMPLOYEE_API_BASE%/}"
else
  API_BASE="${EMPLOYEE_API_BASE%/}/api"
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "❌ curl no está disponible. No se puede ejecutar la limpieza vía API."
  exit 1
fi

if [[ "$CLEAN_ALL" == "true" ]]; then
  echo "🧹 Limpiando TODAS las sesiones del sistema (incluyendo abiertas)..."
  echo "   - Endpoint: ${API_BASE}/debug/cleanup?confirm=yes"

  cleanup_response=$(curl -sf -X DELETE "${API_BASE}/debug/cleanup?confirm=yes" 2>/dev/null) || {
    echo "⚠️  No se pudo limpiar por API. Verifica que el servicio employee esté activo."
    echo "🔄 Intentando limpieza offline directa en base de datos..."

    CLEAN_SCRIPT="${SCRIPT_DIR}/python/clean-sessions.py"
    if [[ -f "${CLEAN_SCRIPT}" ]]; then
       if ! pip3 freeze | grep -q "psycopg2-binary" || ! pip3 freeze | grep -q "redis"; then
          echo "📦 Instalando dependencias para limpieza offline..."
          pip3 install -q psycopg2-binary redis
       fi

       python3 "${CLEAN_SCRIPT}" --all --yes
       echo "✅ Limpieza offline completada"
       exit 0
    else
       echo "❌ No se encontró el script offline ${CLEAN_SCRIPT}"
       exit 1
    fi
  }

  echo "✅ Limpieza completada vía API"
  printf '%s' "${cleanup_response}" | python3 -c 'import json
import sys

try:
    data = json.load(sys.stdin)
    deleted = data.get("deleted", {})
    total = sum(int(value) for value in deleted.values()) if isinstance(deleted, dict) else 0
    print(f"   - Registros eliminados: {total}")
except Exception:
    print("   - Respuesta recibida, pero no se pudo parsear el resumen.")
' || true
  echo ""
  echo "ℹ️  Nota: Los clientes con sesiones locales serán notificados por la validación periódica."
  exit 0
fi

echo "🧹 Limpieza de sesiones cerradas omitida."
echo "   - Usa validaciones periódicas en Supabase o ejecuta con --all para limpieza total vía API."
exit 0
