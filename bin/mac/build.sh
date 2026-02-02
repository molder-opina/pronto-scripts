#!/usr/bin/env bash
# bin/mac/build.sh — Construcción local en macOS con Docker Desktop
# Adaptado para desarrollo local sin sudo
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENV_FILE="${PROJECT_ROOT}/.env"

# Carga variables de entorno
set -a
# shellcheck source=../../.env
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-pronto}"

# macOS/Docker Desktop usa docker compose sin sudo
if ! command -v docker &> /dev/null; then
  echo "❌ Docker no está instalado. Instala Docker Desktop para macOS."
  exit 1
fi

if ! docker compose version &> /dev/null; then
  echo "❌ docker compose no está disponible. Actualiza Docker Desktop."
  exit 1
fi

COMPOSE_CMD=(docker compose -f "${PROJECT_ROOT}/docker-compose.yml" -p "${COMPOSE_PROJECT_NAME}" --env-file "${ENV_FILE}")

AVAILABLE_SERVICES=("client" "employee" "static" "api")

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
  if ! command -v npm &> /dev/null; then
    echo "⚠️  npm no está disponible; omitiendo build de bundles TypeScript."
    return
  fi
  if [[ $need_employees -eq 1 ]]; then
    echo ">> Generando bundle frontend para empleados..."
    (cd "${PROJECT_ROOT}" && npm run build:employees)
  fi
  if [[ $need_clients -eq 1 ]]; then
    echo ">> Generando bundle frontend para clientes..."
    (cd "${PROJECT_ROOT}" && npm run build:clients)
  fi
}

show_usage() {
  cat <<EOF
Uso: $(basename "$0") [opciones] [servicio1] [servicio2] ...

Construye imágenes localmente para desarrollo en macOS.

Servicios disponibles:
  client     - Aplicación de clientes
  employee   - Aplicación de empleados
  api        - API REST Unificada
  static     - Servidor de archivos estáticos (nginx)
  all        - Todos los servicios (por defecto)

Opciones:
  -h, --help       Muestra esta ayuda
  -l, --list       Lista servicios y estado actual
  --no-cache       Reconstruye sin usar caché de Docker
  --pull           Hace pull de las imágenes base antes de construir

Ejemplos:
  $(basename "$0")                    # Construye todos
  $(basename "$0") employee           # Solo employee
  $(basename "$0") --no-cache all     # Fuerza reconstrucción completa
EOF
}

list_services() {
  echo "Servicios disponibles:"
  for service in "${AVAILABLE_SERVICES[@]}"; do
    echo "  - $service"
  done
  echo ""
  echo "Estado actual:"
  "${COMPOSE_CMD[@]}" ps || true
}

# Parseo de argumentos
SERVICES=()
BUILD_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) show_usage; exit 0 ;;
    -l|--list) list_services; exit 0 ;;
    --no-cache) BUILD_ARGS+=("--no-cache"); shift ;;
    --pull) BUILD_ARGS+=("--pull"); shift ;;
    all) SERVICES=(); shift ;;
    client|employee|static|api)
      SERVICES+=("$1"); shift ;;
    *)
      echo "Error: Opción o servicio desconocido '$1'"
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

run_frontend_builds

echo ">> Iniciando build..."
for service in "${SERVICES[@]}"; do
  echo "   - Construyendo ${service}"
  if ((${#BUILD_ARGS[@]} > 0)); then
    "${COMPOSE_CMD[@]}" build "${BUILD_ARGS[@]}" "$service"
  else
    "${COMPOSE_CMD[@]}" build "$service"
  fi
done

echo ""
echo "✅ Build completado"
echo "Puedes desplegar con:"
echo "  bash bin/mac/start.sh client"
