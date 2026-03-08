#!/usr/bin/env bash
set -euo pipefail

# Script para limpiar sesiones antes del redeploy
# Uso: bin/cleanup-old-sessions.sh [--all] [--dry-run]
#   --all: Limpia TODAS las sesiones (incluyendo abiertas)
#   --dry-run: Muestra qué se limpiaría sin ejecutar cambios
#   Sin opciones: wrapper informativo; no realiza limpieza

# Load environment variables if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"
ROOT_ENV_FILE="$(cd "${PROJECT_ROOT}/.." && pwd)/.env"
if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=../.env
  source "${ENV_FILE}"
  set +a
fi
if [[ -f "${ROOT_ENV_FILE}" ]]; then
  set -a
  # shellcheck source=../../.env
  source "${ROOT_ENV_FILE}"
  set +a
fi

show_usage() {
  cat <<EOF
Uso: $(basename "$0") [--all] [--dry-run]

Opciones:
  --all       Limpia TODAS las sesiones (incluyendo abiertas)
  --dry-run   Muestra qué se limpiaría sin ejecutar cambios
  -h, --help  Muestra esta ayuda

Notas:
  - Sin flags, este wrapper no realiza limpieza.
  - Para previsualizar sesiones cerradas, usa: $(basename "$0") --dry-run
  - Para limpieza total, usa: $(basename "$0") --all
  - Para limpieza total segura sin cambios, usa: $(basename "$0") --all --dry-run
EOF
}

log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARN] $1"; }
log_error() { echo "[ERROR] $1" 1>&2; }

normalize_host_postgres() {
  case "${POSTGRES_HOST:-localhost}" in
    postgres|pronto-postgres)
      echo "localhost"
      ;;
    *)
      echo "${POSTGRES_HOST:-localhost}"
      ;;
  esac
}

normalize_host_redis_url() {
  local redis_url="${REDIS_URL:-redis://localhost:6379/0}"
  redis_url="${redis_url/redis:\/\/pronto-redis:/redis://localhost:}"
  redis_url="${redis_url/redis:\/\/redis:/redis://localhost:}"
  echo "${redis_url}"
}

run_offline_cleanup() {
  local clean_script="${SCRIPT_DIR}/python/clean-sessions.py"
  local offline_postgres_host
  local offline_redis_url

  if ! command -v python3 >/dev/null 2>&1; then
    log_error "python3 no está disponible. No se puede usar el fallback offline."
    return 1
  fi

  if [[ ! -f "${clean_script}" ]]; then
    log_error "No se encontró el script offline ${clean_script}"
    return 1
  fi

  local cmd=(python3 "${clean_script}")
  if [[ "${CLEAN_ALL}" == "true" ]]; then
    cmd+=(--all)
  fi
  if [[ "${DRY_RUN}" == "true" ]]; then
    cmd+=(--dry-run)
  fi
  if [[ "${CLEAN_ALL}" == "true" && "${DRY_RUN}" != "true" ]]; then
    cmd+=(--yes)
  fi

  offline_postgres_host="$(normalize_host_postgres)"
  offline_redis_url="$(normalize_host_redis_url)"

  log_info "Ejecutando limpieza offline: ${cmd[*]}"
  log_info "Usando overrides host-local: POSTGRES_HOST=${offline_postgres_host} REDIS_URL=${offline_redis_url}"
  POSTGRES_HOST="${offline_postgres_host}" REDIS_URL="${offline_redis_url}" "${cmd[@]}"
}

# Parse arguments
CLEAN_ALL=false
DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      CLEAN_ALL=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      log_error "Opción desconocida: $1"
      show_usage
      exit 1
      ;;
  esac
done

CANONICAL_API_BASE="${PRONTO_API_URL:-http://localhost:6082}"
if [[ "$CANONICAL_API_BASE" == */api ]]; then
  API_BASE="${CANONICAL_API_BASE%/}"
else
  API_BASE="${CANONICAL_API_BASE%/}/api"
fi

if ! command -v curl >/dev/null 2>&1; then
  log_error "curl no está disponible. No se puede intentar la limpieza vía API."
  exit 1
fi

if [[ "${CLEAN_ALL}" != "true" && "${DRY_RUN}" != "true" ]]; then
  echo "🧹 Limpieza de sesiones cerradas omitida."
  echo "   - Este wrapper ya no limpia nada sin flags explícitos."
  echo "   - Usa --dry-run para previsualizar sesiones cerradas vía script offline."
  echo "   - Usa --all para limpieza total (o --all --dry-run para simular)."
  exit 0
fi

if [[ "${DRY_RUN}" == "true" ]]; then
  if [[ "${CLEAN_ALL}" == "true" ]]; then
    echo "🔍 Previsualizando limpieza TOTAL de sesiones (sin cambios)..."
  else
    echo "🔍 Previsualizando limpieza de sesiones cerradas (sin cambios)..."
  fi
  run_offline_cleanup
  exit $?
fi

if [[ "$CLEAN_ALL" == "true" ]]; then
  echo "🧹 Limpiando TODAS las sesiones del sistema (incluyendo abiertas)..."
  echo "   - Endpoint: ${API_BASE}/debug/cleanup?confirm=yes"

  cleanup_response=$(curl -sf -X DELETE "${API_BASE}/debug/cleanup?confirm=yes" 2>/dev/null) || {
    log_warn "No se pudo limpiar por API canónica (${API_BASE}/debug/cleanup?confirm=yes)."
    log_warn "El endpoint no está disponible en el runtime actual; se usará el script offline si es posible."
    run_offline_cleanup
    exit $?
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
