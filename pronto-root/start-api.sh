#!/usr/bin/env bash
# Start the PRONTO API service for local development (docker compose).
#
# Usage: ./start-api.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log_info() { echo "[INFO] $1"; }
log_success() { echo "[SUCCESS] $1"; }
log_warn() { echo "[WARN] $1"; }
log_error() { echo "[ERROR] $1" 1>&2; }

DOCKER_CONFLICT_OWNERS=""

is_current_service_running() {
  local service="$1"
  local container_id
  container_id="$(docker compose ps --status running -q "$service" 2>/dev/null || true)"
  [ -n "$container_id" ]
}

find_docker_port_owner() {
  local port="$1"
  docker ps --format '{{.Names}}\t{{.Ports}}' | awk -F '\t' -v port="$port" '$2 ~ (":" port "->") {print $1; exit}'
}

find_process_port_owner() {
  local port="$1"
  if ! command -v lsof >/dev/null 2>&1; then
    return 0
  fi
  lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | awk 'NR==2 {print $1 " (pid " $2 ")"; exit}'
}

add_docker_conflict_owner() {
  local owner="$1"
  case " $DOCKER_CONFLICT_OWNERS " in
    *" $owner "*) ;;
    *) DOCKER_CONFLICT_OWNERS="${DOCKER_CONFLICT_OWNERS} ${owner}" ;;
  esac
}

print_port_recovery_help() {
  echo ""
  log_warn "Siguientes pasos sugeridos:"
  echo "  1) Inspecciona listeners activos:"
  echo "     docker ps --format 'table {{.Names}}\t{{.Ports}}'"
  echo "     lsof -nP -iTCP -sTCP:LISTEN | rg ':(5432|6379|6082)'"
  if [ -n "${DOCKER_CONFLICT_OWNERS# }" ]; then
    echo "  2) Si esos puertos pertenecen a otro stack Docker, puedes detener solo esos contenedores:"
    echo "     docker stop${DOCKER_CONFLICT_OWNERS}"
  fi
  echo "  3) Reintenta cuando los puertos estén libres:"
  echo "     ./start-api.sh"
}

check_required_ports() {
  local entries=("postgres:5432" "redis:6379" "api:6082")
  local has_conflicts=0
  local entry service port docker_owner process_owner

  for entry in "${entries[@]}"; do
    service="${entry%%:*}"
    port="${entry##*:}"

    if is_current_service_running "$service"; then
      continue
    fi

    docker_owner="$(find_docker_port_owner "$port")"
    if [ -n "$docker_owner" ]; then
      log_error "Port $port requerido por '$service' ya está ocupado por el contenedor '$docker_owner'."
      add_docker_conflict_owner "$docker_owner"
      has_conflicts=1
      continue
    fi

    process_owner="$(find_process_port_owner "$port")"
    if [ -n "$process_owner" ]; then
      log_error "Port $port requerido por '$service' ya está ocupado por el proceso $process_owner."
      has_conflicts=1
    fi
  done

  if [ "$has_conflicts" -ne 0 ]; then
    log_error "Libera los puertos indicados o detén el stack/proceso paralelo antes de ejecutar ./start-api.sh."
    print_port_recovery_help
    exit 1
  fi
}

echo "PRONTO API Launcher"

if [ -f ".env" ]; then
  log_info "Loading .env"
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

log_info "Checking required ports"
check_required_ports

log_info "Starting docker compose services: postgres, redis, api"
docker compose --profile apps up -d postgres redis api

log_info "Waiting for postgres"
postgres_ready=0
for _ in $(seq 1 30); do
  if docker compose exec -T postgres pg_isready -U "${POSTGRES_USER:-pronto}" -q 2>/dev/null; then
    postgres_ready=1
    log_success "Postgres ready"
    break
  fi
  sleep 1
done

if [ "$postgres_ready" -ne 1 ]; then
  log_error "Postgres no quedó listo dentro del timeout de 30s."
  exit 1
fi

log_success "API running at http://localhost:6082"
