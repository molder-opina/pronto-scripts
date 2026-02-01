#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=bin/lib/docker_runtime.sh
source "${SCRIPT_DIR}/lib/docker_runtime.sh"
# shellcheck source=bin/lib/static_helpers.sh
source "${SCRIPT_DIR}/lib/static_helpers.sh"

ENV_FILE="${PROJECT_ROOT}/config/general.env"
SECRETS_FILE="${PROJECT_ROOT}/config/secrets.env"

# Load environment variables
set -a
# shellcheck source=/dev/null
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"
# shellcheck source=/dev/null
[[ -f "${SECRETS_FILE}" ]] && source "${SECRETS_FILE}"
set +a

COMPOSE_CMD=(sudo docker-compose -f "${PROJECT_ROOT}/docker-compose.yml")

# Servicios disponibles
AVAILABLE_SERVICES=("client" "employee")

show_usage() {
  cat <<EOF
Uso: $(basename "$0") [servicio1] [servicio2] ...

Reinicia servicios específicos del stack Pronto.

Servicios disponibles:
  client     - Aplicación de clientes
  employee   - Aplicación de empleados
  all        - Todos los servicios (por defecto)

Ejemplos:
  $(basename "$0")               # Reinicia todos los servicios
  $(basename "$0") client        # Reinicia solo el servicio de clientes
  $(basename "$0") client employee   # Reinicia clientes y empleados

Opciones:
  -h, --help    Muestra esta ayuda
  -l, --list    Lista todos los servicios disponibles
EOF
}

list_services() {
  echo "Servicios disponibles:"
  for service in "${AVAILABLE_SERVICES[@]}"; do
    echo "  - $service"
  done
  echo ""
  echo "Estado actual:"
  "${COMPOSE_CMD[@]}" ps
}

# Procesar argumentos
SERVICES=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_usage
      exit 0
      ;;
    -l|--list)
      list_services
      exit 0
      ;;
    all)
      SERVICES=()
      break
      ;;
    client|employee)
      SERVICES+=("$1")
      shift
      ;;
    *)
      echo "Error: Servicio desconocido '$1'"
      echo ""
      show_usage
      exit 1
      ;;
  esac
done

# Si no se especificaron servicios, reiniciar todos
if [[ ${#SERVICES[@]} -eq 0 ]]; then
  echo ">> Reiniciando todos los servicios..."
  SERVICES=("${AVAILABLE_SERVICES[@]}")
else
  echo ">> Reiniciando servicios: ${SERVICES[*]}"
fi

# ---------- Cleanup old sessions before restart ----------
# Only cleanup when restarting client or employee services
cleanup_sessions=0
for service in "${SERVICES[@]}"; do
  case "$service" in
    client|employee) cleanup_sessions=1 ;;
  esac
done

if [[ $cleanup_sessions -eq 1 ]]; then
  echo ">> Limpiando todas las sesiones cerradas antes del reinicio..."
  "${SCRIPT_DIR}/cleanup-old-sessions.sh" || {
    echo "⚠️  Advertencia: No se pudieron limpiar las sesiones"
    echo "   Continuando con el reinicio..."
  }
fi

# Reiniciar cada servicio
for service in "${SERVICES[@]}"; do
  echo ">> Reiniciando servicio: $service"
  "${COMPOSE_CMD[@]}" restart "$service"
done

echo ""
echo "✅ Servicios reiniciados exitosamente"
echo ""
echo "Ver logs con:"
for service in "${SERVICES[@]}"; do
  echo "  docker logs pronto-$service -f"
done

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
