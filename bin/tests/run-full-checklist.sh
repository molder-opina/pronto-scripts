#!/usr/bin/env bash
# Ejecuta un checklist completo de infraestructura, APIs y flujos de negocio.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

pass_count=0
fail_count=0
total_count=0

print_check() {
  local status="$1"
  local name="$2"

  case "$status" in
    pending) printf "[ ] %s\n" "$name" ;;
    ok) printf "[x] %s\n" "$name" ;;
    fail) printf "[!] %s\n" "$name" ;;
  esac
}

run_check() {
  local name="$1"
  local cmd="$2"

  total_count=$((total_count + 1))
  print_check pending "$name"
  if eval "$cmd"; then
    pass_count=$((pass_count + 1))
    print_check ok "$name"
  else
    fail_count=$((fail_count + 1))
    print_check fail "$name"
  fi
  echo ""
}

resolve_ports() {
  EMPLOYEE_PORT="${EMPLOYEE_APP_HOST_PORT:-6081}"
  CLIENT_PORT="${CLIENT_APP_HOST_PORT:-6080}"
}

resolve_ports

detect_docker_prefix() {
  DOCKER_PREFIX=()
  if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
      DOCKER_PREFIX=()
    elif command -v sudo >/dev/null 2>&1; then
      DOCKER_PREFIX=("sudo")
    fi
  fi
}

detect_docker_prefix

compose_cmd() {
  if command -v docker-compose >/dev/null 2>&1; then
    echo "${DOCKER_PREFIX[*]} docker-compose -f \"${PROJECT_ROOT}/docker-compose.yml\""
  else
    echo "${DOCKER_PREFIX[*]} docker compose -f \"${PROJECT_ROOT}/docker-compose.yml\""
  fi
}

health_check() {
  local port="$1"
  curl -sf "http://localhost:${port}/api/health" >/dev/null 2>&1
}

check_containers() {
  local app_name="${APP_NAME:-pronto}"
  local employee_name="${app_name}-employee"
  local client_name="${app_name}-client"
  local static_name="${app_name}-static"

  local containers
  containers=$("${DOCKER_PREFIX[@]}" docker ps --format '{{.Names}}' 2>/dev/null | tr '\n' ' ')

  [[ "$containers" == *"$employee_name"* ]] || return 1
  [[ "$containers" == *"$client_name"* ]] || return 1
  [[ "$containers" == *"$static_name"* ]] || return 1
}

echo "Checklist completo - Pronto"
echo "========================================"
echo ""

run_check "Docker disponible" "command -v docker >/dev/null 2>&1"
run_check "Docker Compose disponible" "command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1"
run_check "Servicios docker en ejecucion" "check_containers"

run_check "Employee API health check (localhost:${EMPLOYEE_PORT})" "health_check \"${EMPLOYEE_PORT}\""
run_check "Client API health check (localhost:${CLIENT_PORT})" "health_check \"${CLIENT_PORT}\""

run_check "Datos seed cargados" "bash \"${PROJECT_ROOT}/bin/check-seed-status.sh\""

run_check "Suite API (autenticacion y CRUD)" "bash \"${PROJECT_ROOT}/bin/test-api.sh\""
run_check "Flujo mesero y cocina" "EMPLOYEES_PORT=\"${EMPLOYEE_PORT}\" bash \"${PROJECT_ROOT}/bin/test_waiter_kitchen.sh\""
run_check "Flujo propinas" "CLIENT_APP_HOST_PORT=\"${CLIENT_PORT}\" EMPLOYEE_APP_HOST_PORT=\"${EMPLOYEE_PORT}\" bash \"${PROJECT_ROOT}/bin/test-tips-flow.sh\""
run_check "Flujo compra anonima" "bash \"${PROJECT_ROOT}/bin/test-anonymous.sh\""
run_check "Flujo de pago completo" "EMPLOYEE_APP_HOST_PORT=\"${EMPLOYEE_PORT}\" bash \"${PROJECT_ROOT}/test_payment_flow.sh\""

echo "Resumen"
echo "----------------------------------------"
echo "Checks: ${total_count}"
echo "OK: ${pass_count}"
echo "FAIL: ${fail_count}"

if [ "$fail_count" -gt 0 ]; then
  echo ""
  echo "Hay fallos. Revisa el output anterior para ver los pasos fallidos."
  exit 1
fi

echo ""
echo "Todo OK."
