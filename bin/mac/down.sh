#!/usr/bin/env bash
# bin/mac/down.sh — Detiene servicios localmente en macOS con Docker Desktop
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENV_FILE="${PROJECT_ROOT}/.env"
source "${SCRIPT_DIR}/_check_required_files.sh" 2>/dev/null || true

# Load environment variables
set -a
# shellcheck source=../../.env
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-pronto}"
COMPOSE_CMD=(docker compose -f "${PROJECT_ROOT}/docker-compose.yml" -p "${COMPOSE_PROJECT_NAME}" --env-file "${ENV_FILE}")

echo "🛑 Deteniendo servicios Pronto..."
"${COMPOSE_CMD[@]}" down "$@" 2>/dev/null || true

echo "✅ Servicios detenidos"
