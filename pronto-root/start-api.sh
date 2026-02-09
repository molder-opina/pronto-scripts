#!/usr/bin/env bash
# Start the PRONTO API service for local development (docker compose).
#
# Usage: ./start-api.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

docker compose --profile apps up -d postgres redis api
echo "API running at http://localhost:6082"
