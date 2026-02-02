#!/usr/bin/env bash
# bin/mac/rebuild.sh — Reconstruye y reinicia servicios en macOS con Docker Desktop
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENV_FILE="${PROJECT_ROOT}/.env"

source "${SCRIPT_DIR}/_check_required_files.sh" 2>/dev/null || true

# Source library modules
# shellcheck source=../../bin/lib/static_helpers.sh
source "${SCRIPT_DIR}/../lib/static_helpers.sh"

# Load environment variables
set -a
# shellcheck source=../../.env
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-pronto}"
COMPOSE_CMD=(docker compose -f "${PROJECT_ROOT}/docker-compose.yml" -p "${COMPOSE_PROJECT_NAME}" --env-file "${ENV_FILE}")

KEEP_SESSIONS=false
SERVICES=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      echo "Uso: $(basename "$0") [--keep-sessions] [servicio1] [servicio2] ..."
      echo ""
      echo "Opciones:"
      echo "  -h, --help              Muestra esta ayuda"
      echo "  --keep-sessions, --no-cleanup  Mantiene las sesiones y órdenes (no limpia)"
      echo ""
      echo "Servicios disponibles:"
      echo "  client     - Aplicación de clientes"
      echo "  employee   - Aplicación de empleados"
      echo "  api        - API REST Unificada"
      echo "  static     - Servidor de archivos estáticos (nginx)"
      echo "  redis      - Base de datos Redis"
      echo "  all        - Todos los servicios (por defecto)"
      echo ""
      echo "Ejemplos:"
      echo "  $(basename "$0") employee"
      echo "  $(basename "$0") redis"
      echo "  $(basename "$0") all"
      exit 0
      ;;
    --keep-sessions|--no-cleanup)
      KEEP_SESSIONS=true
      shift
      ;;
    all)
      SERVICES=()
      shift
      ;;
    client|employee|api|static|redis)
      SERVICES+=("$1")
      shift
      ;;
    *)
      echo "Error: Opción o servicio desconocido '$1'"
      echo "Uso: $(basename "$0") [--keep-sessions] [servicio1] [servicio2] ..."
      exit 1
      ;;
  esac
done

if [[ ${#SERVICES[@]} -eq 0 ]]; then
  SERVICES=(client employee api static)
fi

NEEDS_REDIS=false
for s in "${SERVICES[@]}"; do
  if [[ "$s" == "employee" || "$s" == "client" || "$s" == "api" ]]; then
    NEEDS_REDIS=true
    break
  fi
done

# Cleanup old sessions before rebuild (only for client/employee services, unless --keep-sessions)
if [[ "$KEEP_SESSIONS" == "false" ]]; then
  cleanup_sessions=0
  for service in "${SERVICES[@]}"; do
    case "$service" in
      client|employee) cleanup_sessions=1 ;;
    esac
  done

  if [[ $cleanup_sessions -eq 1 ]]; then
    echo ">> Limpiando todas las sesiones antes del redeploy..."
    "${SCRIPT_DIR}/../cleanup-old-sessions.sh" --all || {
      echo "⚠️  Advertencia: No se pudieron limpiar las sesiones"
      echo "   Continuando con el redeploy..."
    }
  fi
else
  echo ">> Manteniendo sesiones y órdenes (--keep-sessions activado)"
fi

# Build frontend if needed
for service in "${SERVICES[@]}"; do
  if [[ "$service" == "employee" ]] && command -v npm &> /dev/null; then
    echo ">> Construyendo bundle TypeScript para empleados..."
    (cd "${PROJECT_ROOT}" && npm run build:employees)
  elif [[ "$service" == "client" ]] && command -v npm &> /dev/null; then
    echo ">> Construyendo bundle TypeScript para clientes..."
    (cd "${PROJECT_ROOT}" && npm run build:clients)
  fi
done

for service in "${SERVICES[@]}"; do
  echo ">> Reconstruyendo ${service}..."

  # Handle Redis and PostgreSQL specially - don't recreate, just ensure running
  if [[ "$service" == "redis" || "$service" == "postgres" ]]; then
    CONTAINER_NAME=""
    if [[ "$service" == "redis" ]]; then
      CONTAINER_NAME="${REDIS_CONTAINER_NAME}"
    else
      CONTAINER_NAME="${POSTGRES_CONTAINER_NAME}"
    fi

    EXISTING_CONTAINER=$(docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" && docker ps --filter "name=${CONTAINER_NAME}" --format '{{.Names}}' || echo "")

    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
      if docker ps --filter "name=${CONTAINER_NAME}" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "   - ${service} ya está corriendo"
        echo "   ✅ ${service} mantenido como está"
      else
        echo "   - ${service} existe pero está detenido, iniciando..."
        docker start "${CONTAINER_NAME}"
        echo "   ✅ ${service} iniciado"
      fi
      continue
    fi
  fi

  # Stop and remove containers using the old image
  echo "   - Deteniendo y removiendo contenedores anteriores..."
  "${COMPOSE_CMD[@]}" stop "${service}" 2>/dev/null || true
  "${COMPOSE_CMD[@]}" rm -f "${service}" 2>/dev/null || true

  # Ensure the host port is free before starting a new container.
  HOST_PORT=""
  case "$service" in
    client) HOST_PORT="${CLIENT_APP_HOST_PORT:-}" ;;
    employee) HOST_PORT="${EMPLOYEE_APP_HOST_PORT:-}" ;;
    api) HOST_PORT="${API_APP_HOST_PORT:-6082}" ;;
    static) HOST_PORT="${STATIC_APP_HOST_PORT:-}" ;;
    redis) HOST_PORT="${REDIS_HOST_PORT:-6379}" ;;
  esac

  if [[ -n "${HOST_PORT}" ]]; then
    echo "   - Verificando puerto ${HOST_PORT}..."
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      container_id=$(awk '{print $1}' <<< "${line}")
      container_name=$(awk '{print $2}' <<< "${line}")
      if [[ -n "${container_id}" ]]; then
        echo "     - Liberando puerto ${HOST_PORT} deteniendo ${container_id} (${container_name})..."
        docker stop "${container_id}" 2>/dev/null || true
        docker rm -f "${container_id}" 2>/dev/null || true
      fi
    done < <(docker ps -a --filter "publish=${HOST_PORT}" --format "{{.ID}} {{.Names}}" 2>/dev/null || true)
  fi

  # Build new image
  echo "   - Construyendo nueva imagen..."
  "${COMPOSE_CMD[@]}" build --no-cache "${service}"

  # Start new container (--no-deps to avoid starting redis/postgres dependencies)
  echo "   - Iniciando nuevo contenedor..."
  "${COMPOSE_CMD[@]}" up -d --no-deps "${service}"

  echo "   ✅ ${service} reconstruido y reiniciado"
  echo ""
done

# Clean up dangling images and build cache
echo ">> Limpiando imágenes huérfanas y caché de build..."
docker image prune -f --filter "dangling=true" 2>/dev/null || true
docker builder prune -f 2>/dev/null || true

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

echo "📊 Estado de servicios:"
"${COMPOSE_CMD[@]}" ps

echo ""
echo "✅ Reconstrucción completada"
