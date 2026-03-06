#!/usr/bin/env bash
# bin/mac/rebuild.sh — Reconstruye y reinicia servicios en macOS con Docker Desktop
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

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

release_port_containers() {
  local host_port="$1"
  [[ -z "${host_port}" ]] && return 0

  echo "   - Verificando puerto ${host_port}..."
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    local container_id
    local container_name
    container_id=$(awk '{print $1}' <<< "${line}")
    container_name=$(awk '{print $2}' <<< "${line}")
    if [[ -n "${container_id}" ]]; then
      echo "     - Liberando puerto ${host_port} deteniendo ${container_id} (${container_name})..."
      docker stop "${container_id}" 2>/dev/null || true
      docker rm -f "${container_id}" 2>/dev/null || true
    fi
  done < <(docker ps -a --filter "publish=${host_port}" --format "{{.ID}} {{.Names}}" 2>/dev/null || true)
}

wait_for_service_health() {
  local service_name="$1"
  local container_id
  container_id=$("${COMPOSE_CMD[@]}" ps -q "${service_name}" 2>/dev/null || true)
  if [[ -z "${container_id}" ]]; then
    echo "   ⚠️  No se encontró contenedor para ${service_name}"
    return 1
  fi

  local status=""
  for _ in {1..30}; do
    status=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${container_id}" 2>/dev/null || echo "unknown")
    if [[ "${status}" == "healthy" || "${status}" == "running" ]]; then
      return 0
    fi
    sleep 2
  done

  echo "   ⚠️  ${service_name} no alcanzó estado healthy/running (estado=${status})"
  return 1
}

ensure_infra_ready() {
  echo ">> Asegurando infraestructura (postgres y redis) antes del redeploy de apps..."
  "${COMPOSE_CMD[@]}" up -d --force-recreate postgres redis
  wait_for_service_health postgres || true
  wait_for_service_health redis || true
}

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
      echo "  postgres   - Base de datos PostgreSQL"
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
    client|employee|api|static|redis|postgres)
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
NEEDS_INFRA=false
for s in "${SERVICES[@]}"; do
  if [[ "$s" == "employee" || "$s" == "client" || "$s" == "api" ]]; then
    NEEDS_REDIS=true
    NEEDS_INFRA=true
    break
  fi
done

if [[ "${NEEDS_INFRA}" == "true" ]]; then
  ensure_infra_ready
fi

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
    (cd "${PROJECT_ROOT}/pronto-static" && npm run build:employees)
  elif [[ "$service" == "client" ]] && command -v npm &> /dev/null; then
    echo ">> Construyendo bundle TypeScript para clientes..."
    (cd "${PROJECT_ROOT}/pronto-static" && npm run build:clients)
  fi
done

for service in "${SERVICES[@]}"; do
  echo ">> Reconstruyendo ${service}..."
  compose_service="${service}"
  if [[ "${service}" == "employee" ]]; then
    compose_service="employees"
  fi

  # Handle Redis and PostgreSQL specially - don't recreate, just ensure running
  if [[ "$service" == "redis" || "$service" == "postgres" ]]; then
    echo "   - Recreando ${service} para asegurar alias de red y estado saludable..."
    "${COMPOSE_CMD[@]}" up -d --force-recreate "${service}"
    wait_for_service_health "${service}" || true
    echo "   ✅ ${service} recreado"
    echo ""
    continue
  fi

  # Stop and remove containers using the old image
  echo "   - Deteniendo y removiendo contenedores anteriores..."
  "${COMPOSE_CMD[@]}" stop "${compose_service}" 2>/dev/null || true
  "${COMPOSE_CMD[@]}" rm -f "${compose_service}" 2>/dev/null || true

  # Ensure the host port is free before starting a new container.
  HOST_PORT=""
  case "$service" in
    client) HOST_PORT="${CLIENT_APP_HOST_PORT:-6080}" ;;
    employee) HOST_PORT="${EMPLOYEE_APP_HOST_PORT:-6081}" ;;
    api) HOST_PORT="${API_APP_HOST_PORT:-6082}" ;;
    static) HOST_PORT="${STATIC_APP_HOST_PORT:-9088}" ;;
    redis) HOST_PORT="${REDIS_HOST_PORT:-6379}" ;;
  esac

  release_port_containers "${HOST_PORT}"

  # Build new image
  echo "   - Construyendo nueva imagen..."
  "${COMPOSE_CMD[@]}" build --no-cache "${compose_service}"

  # Start new container (--no-deps to avoid starting redis/postgres dependencies)
  echo "   - Iniciando nuevo contenedor..."
  up_output=""
  if ! up_output=$("${COMPOSE_CMD[@]}" up -d --no-deps "${compose_service}" 2>&1); then
    if [[ -n "${HOST_PORT}" ]] && grep -qi "port is already allocated" <<< "${up_output}"; then
      echo "   - Detectado conflicto de puerto en ${HOST_PORT}; intentando liberar contenedores activos y reintentar..."
      release_port_containers "${HOST_PORT}"
      "${COMPOSE_CMD[@]}" up -d --no-deps "${compose_service}"
    else
      echo "${up_output}" >&2
      exit 1
    fi
  fi

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
