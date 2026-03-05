#!/usr/bin/env bash
set -euo pipefail

SCOPE="${1:-}"
if [[ -z "${SCOPE}" ]]; then
  echo "Uso: $0 <system|business>"
  exit 1
fi

if [[ "${SCOPE}" != "system" && "${SCOPE}" != "business" ]]; then
  echo "Scope inválido: ${SCOPE}. Usa: system o business"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/.env"
  set +a
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  if [[ -z "${POSTGRES_USER:-}" || -z "${POSTGRES_PASSWORD:-}" || -z "${POSTGRES_HOST:-}" || -z "${POSTGRES_DB:-}" ]]; then
    echo "Falta DATABASE_URL o variables POSTGRES_* para conectar a la base de datos"
    exit 2
  fi
  DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT:-5432}/${POSTGRES_DB}"
fi

python3 - "${ROOT_DIR}" "${SCOPE}" "${DATABASE_URL}" <<'PY'
from __future__ import annotations

import sys

root_dir = sys.argv[1]
scope = sys.argv[2]
database_url = sys.argv[3]

sys.path.insert(0, f"{root_dir}/pronto-libs/src")

try:
    import psycopg2
except Exception as exc:  # pragma: no cover
    print(f"ERROR: psycopg2 no disponible: {exc}")
    raise SystemExit(2)

from pronto_shared.config_contract import CONFIG_CONTRACT, ConfigScope

legacy_keys = {
    "client_session_ttl_seconds",
    "employee_session_ttl_hours",
    "kiosk_session_non_expiring",
    "checkout_prompt_duration_seconds",
    "show_estimated_time",
    "estimated_time_min",
    "estimated_time_max",
    "paid_orders_window_minutes",
    "paid_orders_retention_minutes",
    "items_per_page",
    "RESTAURANT_NAME",
}

scope_enum = ConfigScope.SYSTEM if scope == "system" else ConfigScope.BUSINESS
required_keys = sorted(
    key
    for key, spec in CONFIG_CONTRACT.items()
    if spec.get("scope") == scope_enum
)

try:
    conn = psycopg2.connect(database_url)
except Exception as exc:
    print(f"ERROR: no se pudo conectar a PostgreSQL: {exc}")
    raise SystemExit(2)

with conn:
    with conn.cursor() as cur:
        cur.execute("SELECT key, value FROM pronto_system_settings")
        rows = cur.fetchall()

db_values = {str(key): value for key, value in rows}

missing = [
    key
    for key in required_keys
    if key not in db_values or db_values.get(key) is None or str(db_values.get(key)).strip() == ""
]

legacy_present = sorted(key for key in legacy_keys if key in db_values)

print(f"Scope: {scope}")
print(f"Contract required: {len(required_keys)}")
print(f"Missing required: {len(missing)}")
print(f"Legacy keys present: {len(legacy_present)}")

if missing:
    print("\nFALTAN LLAVES REQUERIDAS:")
    for key in missing:
        print(f"- {key}")

if legacy_present:
    print("\nLLAVES LEGACY DETECTADAS:")
    for key in legacy_present:
        print(f"- {key}")

if missing or legacy_present:
    raise SystemExit(1)

print("\nOK: configuración requerida completa y sin legacy.")
PY
