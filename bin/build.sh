#!/usr/bin/env bash
# bin/build.sh — Construcción de imágenes del stack Pronto/Pronto
# Solo construye imágenes (no detiene ni levanta contenedores).
# Uso:
#   bin/build.sh                 # Construye todos los servicios
#   bin/build.sh employee        # Construye solo employee
#   bin/build.sh client employee # Construye client y employee
#   bin/build.sh --no-cache all  # Fuerza reconstrucción sin caché
#   bin/build.sh --pull          # Hace pull de bases antes de build
#   bin/build.sh -l              # Lista servicios y estado actual

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=bin/lib/docker_runtime.sh
source "${SCRIPT_DIR}/lib/docker_runtime.sh"
# shellcheck source=bin/lib/static_helpers.sh
source "${SCRIPT_DIR}/lib/static_helpers.sh"

ENV_FILE="${PROJECT_ROOT}/.env"
SECRETS_FILE="${PROJECT_ROOT}/.env"

# Carga variables de entorno
set -a
# shellcheck disable=SC1090
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"
# shellcheck disable=SC1090
[[ -f "${SECRETS_FILE}" ]] && source "${SECRETS_FILE}"
set +a

# Nombre de proyecto fijo para evitar nombres "fantasma"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-pronto}"

# Usa docker compose v2 si está disponible, si no cae a docker-compose v1
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose -f "${PROJECT_ROOT}/docker-compose.yml" -p "${COMPOSE_PROJECT_NAME}")
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose -f "${PROJECT_ROOT}/docker-compose.yml" -p "${COMPOSE_PROJECT_NAME}")
else
  echo "❌ No se encontró docker compose. Instala Docker Compose v2 o docker-compose v1."
  exit 1
fi

ensure_compose_access() {
  if "${COMPOSE_CMD[@]}" ps >/dev/null 2>&1; then
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    echo "⚠️  Docker requiere privilegios elevados, reintentando con sudo..."
    COMPOSE_CMD=(sudo "${COMPOSE_CMD[@]}")
    if "${COMPOSE_CMD[@]}" ps >/dev/null 2>&1; then
      echo "✅ Acceso a Docker confirmado usando sudo"
    else
      echo "❌ No se pudo acceder al daemon de Docker. Verifica que esté en ejecución." >&2
      exit 1
    fi
  else
    echo "❌ Docker requiere privilegios elevados y 'sudo' no está disponible." >&2
    exit 1
  fi
}

AVAILABLE_SERVICES=("client" "employee")

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
  if ! command -v npm >/dev/null 2>&1; then
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

show_usage() {
  cat <<EOF
Uso: $(basename "$0") [opciones] [servicio1] [servicio2] ...

Construye imágenes de servicios del stack Pronto (no ejecuta 'up').

Servicios disponibles:
  client     - Aplicación de clientes
  employee   - Aplicación de empleados
  all        - Todos los servicios (por defecto)

Opciones:
  -h, --help       Muestra esta ayuda
  -l, --list       Lista servicios y estado actual
  --no-cache       Reconstruye sin usar caché de Docker
  --pull           Hace pull de las imágenes base antes de construir
  --platform ARG   Pasa --platform (ej. linux/amd64)

Ejemplos:
  $(basename "$0")
  $(basename "$0") employee
  $(basename "$0") --no-cache client employee
  $(basename "$0") --pull all
  $(basename "$0") --platform linux/amd64 employee
EOF
}

list_services() {
  ensure_compose_access
  echo "Servicios disponibles:"
  for service in "${AVAILABLE_SERVICES[@]}"; do
    echo "  - $service"
  done
  echo ""
  echo "Estado actual (compose ps):"
  "${COMPOSE_CMD[@]}" ps || true
}

# ---------- Parseo de argumentos ----------
SERVICES=()
BUILD_ARGS=()
PLATFORM_ARG=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_usage; exit 0 ;;
    -l|--list) list_services; exit 0 ;;
    --no-cache) BUILD_ARGS+=("--no-cache"); shift ;;
    --pull) BUILD_ARGS+=("--pull"); shift ;;
    --platform)
      [[ $# -ge 2 ]] || { echo "Error: --platform requiere un argumento"; exit 1; }
      PLATFORM_ARG=(--build-arg "TARGET_PLATFORM=$2" --platform "$2")
      shift 2
      ;;
    all) SERVICES=(); shift ;;
    client|employee)
      SERVICES+=("$1"); shift ;;
    *)
      echo "Error: Opción o servicio desconocido '$1'"
      echo ""
      show_usage
      exit 1
      ;;
  esac
done

# Si no se especificaron servicios, construye todos
if [[ ${#SERVICES[@]} -eq 0 ]]; then
  echo ">> Construyendo todos los servicios..."
  SERVICES=("${AVAILABLE_SERVICES[@]}")
else
  echo ">> Construyendo servicios: ${SERVICES[*]}"
fi

ensure_compose_access
run_frontend_builds

# ---------- Construcción ----------
echo ">> Iniciando build..."
for service in "${SERVICES[@]}"; do
  echo "   - Construyendo ${service}"
  # docker compose v2 permite: compose build [args] SERVICE
  # docker-compose v1 también soporta lo mismo.
  "${COMPOSE_CMD[@]}" build "${BUILD_ARGS[@]}" "${PLATFORM_ARG[@]}" "$service"
done

echo ""
echo "✅ Build completado"
echo "Puedes desplegar con:"
echo "  bin/rebuild.sh ${SERVICES[*]}"

# ---------- Sincronizar estáticos a nginx local (si existe) ----------
NGINX_STATIC_ROOT="/var/www/pronto-static"
if [[ -d "${NGINX_STATIC_ROOT}" ]]; then
  echo ">> Sincronizando assets al nginx local en ${NGINX_STATIC_ROOT} ..."
  # JS compilado clientes
  sudo install -d "${NGINX_STATIC_ROOT}/assets/js/clients" || true
  sudo rsync -a "${PROJECT_ROOT}/pronto-static/src/static_content/assets/js/clients/" "${NGINX_STATIC_ROOT}/assets/js/clients/" || true
  # JS compilado empleados
  sudo install -d "${NGINX_STATIC_ROOT}/assets/js/employees" || true
  sudo rsync -a "${PROJECT_ROOT}/pronto-static/src/static_content/assets/js/employees/" "${NGINX_STATIC_ROOT}/assets/js/employees/" || true
  # CSS
  sudo install -d "${NGINX_STATIC_ROOT}/assets/css" || true
  sudo rsync -a "${PROJECT_ROOT}/pronto-static/src/static_content/assets/css/" "${NGINX_STATIC_ROOT}/assets/css/" || true
  # Plantilla base (si existe)
  sudo rsync -a "${PROJECT_ROOT}/pronto-client/src/pronto_clients/templates/base.html" "${NGINX_STATIC_ROOT}/base.html" || true
  # Assets (imágenes, íconos, libs locales)
  sudo rsync -a "${PROJECT_ROOT}/pronto-static/src/static_content/assets/" "${NGINX_STATIC_ROOT}/assets/" || true
  # Evitar 403 en /assets por permisos restrictivos heredados del repo (nginx necesita +x en dirs y +r en archivos)
  sudo chmod -R a+rX "${NGINX_STATIC_ROOT}/assets" 2>/dev/null || true
  echo ">> Sincronización de estáticos a nginx completada."
else
  echo "ℹ️  No se encontró ${NGINX_STATIC_ROOT}; omitiendo sync a nginx local."
fi

# Validate static pod (for client and employee services)
NEEDS_STATIC_VALIDATION=false
for service in "${SERVICES[@]}"; do
  if [[ "$service" == "client" || "$service" == "employee" ]]; then
    NEEDS_STATIC_VALIDATION=true
    break
  fi
done

if [[ "$NEEDS_STATIC_VALIDATION" == "true" ]]; then
  validate_static_pod || echo "   ⚠️  Continuar sin validación de contenido estático"
fi
