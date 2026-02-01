#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source library modules
# shellcheck source=bin/lib/docker_runtime.sh
source "${SCRIPT_DIR}/lib/docker_runtime.sh"
# shellcheck source=bin/lib/stack_helpers.sh
source "${SCRIPT_DIR}/lib/stack_helpers.sh"
# shellcheck source=bin/lib/build_helpers.sh
source "${SCRIPT_DIR}/lib/build_helpers.sh"
# shellcheck source=bin/lib/cleanup_helpers.sh
source "${SCRIPT_DIR}/lib/cleanup_helpers.sh"
# shellcheck source=bin/lib/static_helpers.sh
source "${SCRIPT_DIR}/lib/static_helpers.sh"

ENV_FILE_DOT="${PROJECT_ROOT}/.env"
ENV_FILE="${PROJECT_ROOT}/config/general.env"
SECRETS_FILE="${PROJECT_ROOT}/config/secrets.env"
LOAD_SEED=false

# Carga variables de entorno
set -a
# shellcheck disable=SC1090
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"
# shellcheck disable=SC1090
[[ -f "${SECRETS_FILE}" ]] && source "${SECRETS_FILE}"
set +a

# Detectar runtime/compose disponible
detect_compose_command "${PROJECT_ROOT}/docker-compose.yml"

# Nombre de proyecto para filtrar contenedores
PROJECT_PREFIX="${PROJECT_PREFIX:-pronto}"

AVAILABLE_SERVICES=("client" "employee")

show_usage() {
  cat <<EOF
Uso: $(basename "$0") [opciones] [servicio1] [servicio2] ...

Reconstruye y redespliega servicios específicos del stack Pronto.

Servicios disponibles:
  client     - Aplicación de clientes
  employee   - Aplicación de empleados
  all        - Todos los servicios (client + employee)

Opciones:
  -h, --help       Muestra esta ayuda
  -l, --list       Lista todos los servicios y estado
  --no-cache       Reconstruye sin usar cache de Docker
  --pull           Hace pull de las imágenes base antes de construir
  --seed           Carga/actualiza 94+ productos de prueba al iniciar (UPSERT)
  --keep-sessions  Mantiene las sesiones y órdenes (no limpia antes del rebuild)

Ejemplos:
  $(basename "$0") client
  $(basename "$0") client employee
  $(basename "$0") --no-cache client
  $(basename "$0") --seed client employee
  $(basename "$0") --keep-sessions client employee
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

# ---------- Parseo de argumentos ----------
SERVICES=()
BUILD_ARGS=()
KEEP_SESSIONS=false
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) show_usage; exit 0;;
    -l|--list) list_services; exit 0;;
    --no-cache) BUILD_ARGS+=("--no-cache"); shift;;
    --pull) BUILD_ARGS+=("--pull"); shift;;
    --seed) LOAD_SEED=true; shift;;
    --keep-sessions) KEEP_SESSIONS=true; shift;;
    all) SERVICES=(); break;;
    client|employee) SERVICES+=("$1"); shift;;
    *)
      echo "Error: Opción o servicio desconocido '$1'"
      echo ""
      show_usage
      exit 1
      ;;
  esac
done

# Si no se especificaron servicios, reconstruir todos
if [[ ${#SERVICES[@]} -eq 0 ]]; then
  echo ">> Reconstruyendo todos los servicios..."
  SERVICES=("${AVAILABLE_SERVICES[@]}")
else
  echo ">> Reconstruyendo servicios: ${SERVICES[*]}"
fi

# Enable seed data loading if --seed flag was provided
if [ "$LOAD_SEED" = true ]; then
  echo ">> Habilitando LOAD_SEED_DATA temporalmente..."
  if [[ -f "${ENV_FILE_DOT}" ]]; then
    sed -i 's/^LOAD_SEED_DATA=.*/LOAD_SEED_DATA=true/' "${ENV_FILE_DOT}"
  fi
fi

# ---------- Cleanup old sessions before rebuild ----------
if [[ "$KEEP_SESSIONS" == "false" ]]; then
  cleanup_sessions=0
  for service in "${SERVICES[@]}"; do
    case "$service" in
      client|employee) cleanup_sessions=1 ;;
    esac
  done

  if [[ $cleanup_sessions -eq 1 ]]; then
    echo ">> Limpiando todas las sesiones cerradas antes del redeploy..."
    "${SCRIPT_DIR}/cleanup-old-sessions.sh" --all || {
      echo "⚠️  Advertencia: No se pudieron limpiar las sesiones"
      echo "   Continuando con el redeploy..."
    }
  fi
else
  echo ">> Manteniendo sesiones y órdenes (--keep-sessions activado)"
fi

# ---------- Verificación y Validación de Postgres ----------
echo ">> Verificando estado de PostgreSQL..."
POSTGRES_CONTAINER_NAME="${PROJECT_PREFIX}-postgres"
POSTGRES_EXISTS=false

if "${CONTAINER_CLI}" ps -a --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER_NAME}$"; then
    POSTGRES_EXISTS=true
    if "${CONTAINER_CLI}" ps --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER_NAME}$"; then
       echo "   ✅ PostgreSQL (${POSTGRES_CONTAINER_NAME}) está activo y en ejecución."
    else
       echo "   ⚠️  PostgreSQL (${POSTGRES_CONTAINER_NAME}) existe pero está detenido. Iniciándolo..."
       "${CONTAINER_CLI}" start "${POSTGRES_CONTAINER_NAME}" || echo "      No se pudo iniciar postgres directamente."
    fi
else
    echo "   ℹ️  PostgreSQL no detectado. Se iniciará con el stack."
fi

# ---------- Verificación y Validación de Redis ----------
echo ">> Verificando estado de Redis..."
REDIS_CONTAINER_NAME="${PROJECT_PREFIX}-redis"
REDIS_EXISTS=false
REDIS_RUNNING=false

if "${CONTAINER_CLI}" ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${REDIS_CONTAINER_NAME}$"; then
    REDIS_EXISTS=true
    if "${CONTAINER_CLI}" ps --format '{{.Names}}' 2>/dev/null | grep -q "^${REDIS_CONTAINER_NAME}$"; then
        REDIS_RUNNING=true
        echo "   ✅ Redis (${REDIS_CONTAINER_NAME}) está activo y en ejecución."
    else
        echo "   ⚠️  Redis (${REDIS_CONTAINER_NAME}) existe pero está detenido. Iniciándolo..."
        "${CONTAINER_CLI}" start "${REDIS_CONTAINER_NAME}" 2>/dev/null && echo "      ✅ Redis iniciado correctamente." || {
            echo "      ⚠️  No se pudo iniciar redis directamente. Se recreará con el stack."
            REDIS_RUNNING=false
        }
    fi
else
    echo "   ℹ️  Redis no detectado. Se iniciará con el stack."
fi

# ---------- Stop & rm via compose ----------
echo ">> Deteniendo y eliminando servicios existentes..."

POSTGRES_RUNNING=false
if "${CONTAINER_CLI}" ps --format '{{.Names}}' 2>/dev/null | grep -q "^${PROJECT_PREFIX}-postgres$"; then
    POSTGRES_RUNNING=true
    echo "   - Detectado contenedor ${PROJECT_PREFIX}-postgres en ejecución (se mantendrá)"
fi

for service in "${SERVICES[@]}"; do
  if [[ "$service" == "postgres" ]]; then
    echo "   - Omitiendo postgres (ya existe o se gestiona externamente)"
    continue
  fi

  "${COMPOSE_CMD[@]}" stop -t 10 "$service" 2>/dev/null || true
  "${COMPOSE_CMD[@]}" rm -f -s "$service" 2>/dev/null || true

  # Liberar puerto del host
  HOST_PORT=""
  case "$service" in
    client) HOST_PORT="${CLIENT_APP_HOST_PORT:-}" ;;
    employee) HOST_PORT="${EMPLOYEE_APP_HOST_PORT:-}" ;;
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
done

# ---------- Limpieza forzada por nombre ----------
echo ">> Limpieza forzada de contenedores atascados..."
for service in "${SERVICES[@]}"; do
  if [[ "$service" == "postgres" ]]; then
    echo "   - Omitiendo postgres de la limpieza forzada"
    continue
  fi

  pattern="^${PROJECT_PREFIX}-${service}($|-)"
  MATCHED=()
  while IFS= read -r name; do
    [[ -n "${name}" ]] && MATCHED+=("${name}")
  done < <("${CONTAINER_CLI}" ps -a --format '{{.Names}}' | grep -E "${pattern}" || true)
  for name in "${MATCHED[@]-}"; do
    [[ -z "${name}" ]] && continue
    echo "   - Forzando eliminación: $name"
    kill_and_rm_by_name "$name"
  done
done

# ---------- Limpieza de imágenes antiguas ----------
cleanup_old_images "${SERVICES[@]}"

# ---------- Reconstrucción ----------
prepare_dependencies
run_frontend_builds
echo ">> Reconstruyendo imágenes..."
for service in "${SERVICES[@]}"; do
  if [[ "$service" == "postgres" ]]; then
    echo "   - Omitiendo postgres (ya existe)"
    continue
  fi
  echo "   - Construyendo $service"
  if ((${#BUILD_ARGS[@]} > 0)); then
    "${COMPOSE_CMD[@]}" build "${BUILD_ARGS[@]}" "$service"
  else
    "${COMPOSE_CMD[@]}" build "$service"
  fi
done

# ---------- Up ----------
echo ">> Levantando servicios reconstruidos..."
SERVICES_TO_UP=()

# Redis: solo incluir si NO está ya en ejecución (evita conflicto de container name)
if [[ "$REDIS_RUNNING" == "true" ]]; then
    echo "   ✅ Redis ya está en ejecución, omitiendo inicio."
elif [[ "$POSTGRES_EXISTS" == "true" ]]; then
    # Solo incluir redis si postgres existe Y redis NO está corriendo
    SERVICES_TO_UP+=("redis")
fi

for service in "${SERVICES[@]}"; do
  if [[ "$service" != "postgres" ]]; then
    SERVICES_TO_UP+=("$service")
  fi
done

UP_FLAGS="-d --remove-orphans"
if [[ "$POSTGRES_EXISTS" == "true" && "$REDIS_RUNNING" == "false" ]]; then
    UP_FLAGS="$UP_FLAGS --no-deps"
    echo "   ℹ️  Modo sin dependencias activado (PostgreSQL externo detectado)."
fi

# Solo hacer up si hay servicios para levantar
if [[ ${#SERVICES_TO_UP[@]} -gt 0 ]]; then
    "${COMPOSE_CMD[@]}" up $UP_FLAGS "${SERVICES_TO_UP[@]}"
else
    echo "   ℹ️  No hay servicios que iniciar (redis ya estaba activo)."
fi

# ---------- Sincronizar estáticos ----------
sync_static_content "${SERVICES[@]}"

# ---------- Validar pod estático ----------
# Validar que el servidor de contenido estático esté disponible
# (advertencia solamente, no bloquea el despliegue)
validate_static_pod || echo "   ⚠️  Continuar sin validación de contenido estático"


# Restore LOAD_SEED_DATA to false after services start
if [ "$LOAD_SEED" = true ]; then
  echo ">> Esperando 30 segundos para que se carguen los datos..."
  if [[ -f "${ENV_FILE_DOT}" ]]; then
    sleep 30
    echo ">> Restaurando LOAD_SEED_DATA=false en .env..."
    sed -i 's/^LOAD_SEED_DATA=.*/LOAD_SEED_DATA=false/' "${ENV_FILE_DOT}"
  fi
fi

echo ""
echo "✅ Servicios reconstruidos y desplegados exitosamente"
if [ "$LOAD_SEED" = true ]; then
  echo "   📦 Datos de prueba cargados/actualizados (94+ productos)"
fi
echo ""
echo "Ver logs con:"
for service in "${SERVICES[@]}"; do
  echo "  ${CONTAINER_CLI} logs ${PROJECT_PREFIX}-${service} -f"
done
echo ""
echo "Estado de los servicios:"
"${COMPOSE_CMD[@]}" ps "${SERVICES[@]}" || true
