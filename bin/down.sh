#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=bin/lib/docker_runtime.sh
source "${SCRIPT_DIR}/lib/docker_runtime.sh"
# shellcheck source=bin/lib/stack_helpers.sh
source "${SCRIPT_DIR}/lib/stack_helpers.sh"

ENV_FILE="${PROJECT_ROOT}/config/general.env"
SECRETS_FILE="${PROJECT_ROOT}/config/secrets.env"

# Load environment variables
set -a
# shellcheck source=/dev/null
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"
# shellcheck source=/dev/null
[[ -f "${SECRETS_FILE}" ]] && source "${SECRETS_FILE}"
set +a

detect_compose_command "${PROJECT_ROOT}/docker-compose.yml"

clean_pronto_containers() {
  local bases=("pronto-client" "pronto-employee" "pronto-static")
  for base in "${bases[@]}"; do
    mapfile -t containers < <("${CONTAINER_CLI}" ps -a --format '{{.Names}}' | grep -E "^${base}-" || true)
    for name in "${containers[@]}"; do
      [[ -z "${name}" ]] && continue
      echo ">> Removing container ${name}"
      "${CONTAINER_CLI}" rm -f "${name}" >/dev/null 2>&1 || true
    done
  done
}

echo ">> Stopping Pronto stack..."
"${COMPOSE_CMD[@]}" down --remove-orphans "$@" >/dev/null 2>&1 || true
clean_pronto_containers
