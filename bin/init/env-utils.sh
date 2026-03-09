#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

ensure_file_exists() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "❌ Archivo no encontrado: $file" >&2
    return 1
  fi
}

backup_file() {
  local source_file="$1"
  local backup_dir="$2"
  mkdir -p "$backup_dir"
  if [ -f "$source_file" ]; then
    local filename
    filename=$(basename "$source_file")
    cp "$source_file" "${backup_dir}/${filename}"
    echo "✅ Backup: ${backup_dir}/${filename}"
  else
    echo "⚠️  No existe: $source_file"
  fi
}

replace_env_file() {
  local target_file="$1"
  local source_file="$2"
  ensure_file_exists "$source_file"
  cp "$source_file" "$target_file"
}

update_env_key() {
  local target_file="$1"
  local key="$2"
  local value="$3"

  python3 - "$target_file" "$key" "$value" <<'PY'
import sys
from pathlib import Path

file_path = Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]

lines = []
if file_path.exists():
    lines = file_path.read_text().splitlines(keepends=True)

updated = False
for idx, line in enumerate(lines):
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        continue
    if stripped.startswith("export "):
        stripped = stripped[len("export "):].strip()
    if not stripped.startswith(f"{key}="):
        continue
    prefix = "export " if line.lstrip().startswith("export ") else ""
    lines[idx] = f"{prefix}{key}={value}\n"
    updated = True
    break

if not updated:
    lines.append(f"{key}={value}\n")

file_path.write_text("".join(lines))
PY
}

resolve_backup_dir() {
  local tag="$1"
  local timestamp
  timestamp=$(date "+%Y%m%d-%H%M%S")
  echo "${PROJECT_ROOT}/backups/${tag}-${timestamp}"
}
