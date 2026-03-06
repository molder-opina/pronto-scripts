#!/usr/bin/env bash
set -e

echo "✍️  [AGENTE SCRIBE] Verificando documentación..."

EXIT_CODE=0

# 1. Check for CHANGELOG updates if version changes
# This is a heuristic: if package.json or pyproject.toml is modified, CHANGELOG should likely be too.
# Since pre-commit runs on staged files, we can check if version files are staged.
# Limitation: straightforward shell check might not detect 'staged' status easily without git commands.
# We will skip complex logic and just do content checks.

# 2. Check for TODOs in Documentation
echo "   - Buscando TODOs en documentación..."
if grep -r "TODO" pronto-docs/ AGENTS.md README.md --include="*.md" > /dev/null 2>&1; then
    echo "   ⚠️  Advertencia: Hay 'TODO' pendientes en la documentación."
    # grep -r "TODO" docs/ AGENTS.md README.md --include="*.md" | head -n 3
else
    echo "   ✅ Documentación limpia de TODOs."
fi

# 3. Check for broken links in Markdown (simple regex for internal links)
# echo "   - Verificando enlaces rotos simples..."
# heuristic for [Label](path/to/file) where file doesn't exist
# grep -rE "\[.*\]\((.*)\)" docs/ | ... (complex to implement in bash robustly, skipping)

# 4. Verify AGENTS.md structure (Critical file)
if [ ! -f "AGENTS.md" ]; then
    echo "   ❌ Error: AGENTS.md no existe. Es crítico para el sistema."
    EXIT_CODE=1
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "📜 [AGENTE SCRIBE] Visto Bueno (VoBo) ✅"
else
    echo "📜 [AGENTE SCRIBE] Rechazado ❌"
fi

exit $EXIT_CODE
