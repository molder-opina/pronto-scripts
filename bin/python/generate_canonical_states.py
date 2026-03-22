#!/usr/bin/env python3
"""Generate canonical-states.ts from backend constants.py.

Usage:
    python3 pronto-scripts/bin/python/generate_canonical_states.py

This reads all status enums from pronto_shared/constants.py and writes
the canonical TypeScript file that the frontend uses.

If the generated content differs from the existing file, the script exits
with code 1, which can be used as a CI check.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
CONSTANTS_PY = REPO_ROOT / "pronto-libs/src/pronto_shared/constants.py"
CANONICAL_STATES_TS = (
    REPO_ROOT / "pronto-static/src/vue/shared/lib/canonical-states.ts"
)

# Map Python enum class names to TypeScript const/type names
ENUM_MAP = {
    "OrderStatus": "ORDER_STATUS",
    "SessionStatus": "SESSION_STATUS",
    "PaymentStatus": "PAYMENT_STATUS",
    "TableStatus": "TABLE_STATUS",
    "WaiterCallStatus": "WAITER_CALL_STATUS",
}


def extract_enum_values(source: str, enum_name: str) -> list[str]:
    """Extract values from a Python str,Enum class."""
    pattern = re.compile(
        rf"class {enum_name}\(str,\s*Enum\):(.*?)(?=\nclass |\Z)",
        re.DOTALL,
    )
    match = pattern.search(source)
    if not match:
        return []
    body = match.group(1)
    return re.findall(r'=\s*"([^"]+)"', body)


def generate_ts(py_source: str) -> str:
    """Generate the TypeScript canonical states file content."""
    lines: list[str] = [
        "/**",
        " * ⚠️ AUTO-GENERATED FILE",
        " *",
        " * Generated from:",
        " * pronto-libs/src/pronto_shared/constants.py",
        " *",
        " * DO NOT EDIT MANUALLY.",
        " * Changes will be overwritten.",
        " *",
        " * Generator: pronto-scripts/bin/python/generate_canonical_states.py",
        " */",
        "",
    ]

    for py_enum, ts_const in ENUM_MAP.items():
        values = extract_enum_values(py_source, py_enum)
        if not values:
            print(f"WARNING: No values found for {py_enum}", file=sys.stderr)
            continue

        ts_type = py_enum
        values_str = ", ".join(f'"{v}"' for v in values)
        lines.append(
            f"export const {ts_const} = [{values_str}] as const;"
        )
        lines.append(
            f"export type {ts_type} = typeof {ts_const}[number];"
        )
        lines.append("")

    # Add the status translator utility
    lines.extend([
        "// Status translator using i18n",
        "import { useI18n } from 'vue-i18n';",
        "",
        "export const useStatusTranslator = () => {",
        "  const { t } = useI18n();",
        "  ",
        "  const translateStatus = (type: string, status: string): string => {",
        "    const key = `status.${type}.${status}`;",
        "    return t(key, status);",
        "  };",
        "  ",
        "  return { translateStatus };",
        "};",
        "",
    ])

    return "\n".join(lines)


def main() -> int:
    if not CONSTANTS_PY.exists():
        print(f"ERROR: {CONSTANTS_PY} not found", file=sys.stderr)
        return 1

    py_source = CONSTANTS_PY.read_text(encoding="utf-8")
    generated = generate_ts(py_source)

    check_only = "--check" in sys.argv

    if check_only:
        if not CANONICAL_STATES_TS.exists():
            print(f"ERROR: {CANONICAL_STATES_TS} not found", file=sys.stderr)
            return 1

        existing = CANONICAL_STATES_TS.read_text(encoding="utf-8")
        if existing.strip() == generated.strip():
            print("✅ canonical-states.ts is in sync with constants.py")
            return 0
        else:
            print(
                "❌ canonical-states.ts is OUT OF SYNC with constants.py",
                file=sys.stderr,
            )
            print(
                "   Run: python3 pronto-scripts/bin/python/generate_canonical_states.py",
                file=sys.stderr,
            )
            return 1
    else:
        CANONICAL_STATES_TS.write_text(generated, encoding="utf-8")
        print(f"✅ Generated {CANONICAL_STATES_TS}")
        return 0


if __name__ == "__main__":
    sys.exit(main())
