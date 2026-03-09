#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${1:-$HOME/.vibe/config.toml}"

if ! command -v ollama >/dev/null 2>&1; then
  echo "ollama not found in PATH"
  exit 1
fi

if [ ! -f "$CONFIG_PATH" ]; then
  echo "config not found: $CONFIG_PATH"
  exit 1
fi

python3 - "$CONFIG_PATH" <<'PY'
from __future__ import annotations

import re
import subprocess
import sys

config_path = sys.argv[1]

output = subprocess.check_output(["ollama", "ls"], text=True)
lines = [line.strip() for line in output.splitlines() if line.strip()]
if len(lines) <= 1:
    raise SystemExit("No models found in ollama ls")

models: list[str] = []
for line in lines[1:]:
    name = line.split()[0]
    if "embed" in name.lower():
        continue
    models.append(name)

def make_alias(name: str) -> str:
    alias = name.replace(":", "-")
    alias = re.sub(r"[^a-zA-Z0-9._-]+", "-", alias)
    return f"{alias}-local"

def make_block(name: str) -> str:
    return "\n".join(
        [
            "[[models]]",
            f'name = "{name}"',
            'provider = "ollama"',
            f'alias = "{make_alias(name)}"',
            "temperature = 0.2",
            "input_price = 0.0",
            "output_price = 0.0",
            "",
        ]
    )

new_blocks = [make_block(name) for name in models]

with open(config_path, "r", encoding="utf-8") as f:
    text = f.read()

pattern = re.compile(r"(?ms)^\[\[models\]\]\r?\n.*?(?=^\[\[models\]\]|\Z)")
matches = list(pattern.finditer(text))
if not matches:
    raise SystemExit("No [[models]] blocks found in config")

pre = text[: matches[0].start()]
post = text[matches[-1].end() :]

kept_blocks: list[str] = []
inserted = False
for match in matches:
    block = match.group(0)
    provider_match = re.search(r'^provider\s*=\s*"([^"]+)"', block, re.MULTILINE)
    provider = provider_match.group(1) if provider_match else ""
    if provider == "ollama":
        if not inserted:
            kept_blocks.extend(new_blocks)
            inserted = True
        continue
    kept_blocks.append(block.rstrip() + "\n")

if not inserted:
    kept_blocks.extend(new_blocks)

new_text = pre + "".join(kept_blocks) + post

with open(config_path, "w", encoding="utf-8") as f:
    f.write(new_text)
PY

echo "Updated ollama models in $CONFIG_PATH"
