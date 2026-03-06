#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
RUNNER="$REPO_ROOT/pronto-tests/scripts/run-tests.sh"

if [[ ! -x "$RUNNER" ]]; then
  echo "ERROR: runner not found: $RUNNER" >&2
  exit 1
fi

echo "[DEPRECATED] pronto-scripts/bin/test-all.sh"
echo "Delegating to pronto-tests/scripts/run-tests.sh functionality"

exec "$RUNNER" functionality
