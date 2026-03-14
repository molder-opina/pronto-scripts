#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[Init/Seeds Sync] No se encontró repo git de pronto-scripts en $REPO_ROOT" >&2
  exit 1
fi

cd "$REPO_ROOT"

STAGED_FILES="$(git -C "$REPO_ROOT" diff --cached --name-only)"

if [[ -z "$STAGED_FILES" ]]; then
  exit 0
fi

STRUCTURAL_REGEX='(^pronto-libs/src/pronto_shared/models/.*\.py$|^src/pronto_shared/models/.*\.py$|^pronto-libs/src/pronto_shared/models\.py$|^src/pronto_shared/models\.py$|^pronto-(api|employees|client)/src/.*/models/.*\.py$|^src/(api_app|pronto_employees|pronto_clients)/.*/models/.*\.py$)'
INIT_REGEX='^(pronto-scripts/init/sql/|init/sql/)'
SEED_REGEX='^(pronto-scripts/init/sql/40_seeds/|init/sql/40_seeds/)'

HAS_STRUCTURAL=0
HAS_INIT=0
HAS_SEED=0

if printf '%s\n' "$STAGED_FILES" | rg -n --pcre2 "$STRUCTURAL_REGEX" >/dev/null 2>&1; then
  HAS_STRUCTURAL=1
fi

if printf '%s\n' "$STAGED_FILES" | rg -n --pcre2 "$INIT_REGEX" >/dev/null 2>&1; then
  HAS_INIT=1
fi

if printf '%s\n' "$STAGED_FILES" | rg -n --pcre2 "$SEED_REGEX" >/dev/null 2>&1; then
  HAS_SEED=1
fi

if (( HAS_STRUCTURAL == 0 && HAS_INIT == 0 )); then
  exit 0
fi

if (( HAS_STRUCTURAL == 1 && HAS_INIT == 0 )); then
  cat >&2 <<'EOF'
[Init/Seeds Sync] Se detectaron cambios estructurales en modelos persistentes.
Pregunta obligatoria: ¿ya actualizaste los scripts correspondientes en `pronto-scripts/init/sql/**` y seeds en `40_seeds/**`?

Antes de continuar valida:
  ./pronto-scripts/bin/pronto-migrate --check
  ./pronto-scripts/bin/pronto-init --check

Luego confirma explícitamente el gate con:
  PRONTO_INIT_SEED_VALIDATED=1 git commit ...

Si no hubo impacto en seeds, añade también:
  PRONTO_INIT_SEED_NO_DATA_CHANGE=1
EOF
  exit 1
fi

if (( HAS_STRUCTURAL == 1 && HAS_SEED == 0 )) && [[ "${PRONTO_INIT_SEED_NO_DATA_CHANGE:-0}" != "1" ]]; then
  cat >&2 <<'EOF'
[Init/Seeds Sync] Cambio estructural detectado sin actualización staged en `40_seeds/**`.
Si realmente no hay impacto de datos base/catálogos, confirma con:
  PRONTO_INIT_SEED_NO_DATA_CHANGE=1
EOF
  exit 1
fi

if [[ "${PRONTO_INIT_SEED_VALIDATED:-0}" != "1" ]]; then
  cat >&2 <<'EOF'
[Init/Seeds Sync] Confirmación faltante.
Pregunta obligatoria: ¿validaste `pronto-migrate --check` y `pronto-init --check`?

Para continuar:
  PRONTO_INIT_SEED_VALIDATED=1 git commit ...
EOF
  exit 1
fi

echo "[Init/Seeds Sync] OK (confirmado por PRONTO_INIT_SEED_VALIDATED=1)"
