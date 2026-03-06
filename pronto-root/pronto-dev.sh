#!/usr/bin/env bash
# PRONTO Development Launcher (root workspace)
# Starts docker compose services and runs canonical DB init checks.
#
# Usage: ./pronto-dev.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "PRONTO Development Launcher"

if [ -f ".env" ]; then
  echo "[INFO] Loading .env"
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
else
  echo "[ERROR] .env not found in repo root" 1>&2
  exit 1
fi

echo "[INFO] Starting docker compose (apps profile)"
docker compose --profile apps up -d

echo "[INFO] Waiting for postgres"
for _ in $(seq 1 30); do
  if docker compose exec -T postgres pg_isready -U "${POSTGRES_USER:-pronto}" -q 2>/dev/null; then
    echo "[SUCCESS] Postgres ready"
    break
  fi
  sleep 1
done

export DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}"

echo "[INFO] Checking DB init"
if ! ./pronto-scripts/bin/pronto-init --check 2>/dev/null | rg -q "\"ok\":\\s*true"; then
  echo "[INFO] Applying init"
  ./pronto-scripts/bin/pronto-init --apply
else
  echo "[SUCCESS] DB init OK"
fi

echo ""
echo "URLs:"
echo "  client:    http://localhost:6080"
echo "  employees: http://localhost:6081"
echo "  api:       http://localhost:6082"
echo "  static:    http://localhost:9088"
