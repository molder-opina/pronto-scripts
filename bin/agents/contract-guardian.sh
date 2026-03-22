#!/usr/bin/env bash
set -e

echo "🔍 [CONTRACT GUARDIAN] Iniciando revisión de contratos Frontend-Backend..."

cd "$(dirname "$0")/../../.."

EXIT_CODE=0

echo "   - Verificando sincronización de canonical-states.ts con constants.py..."
if python3 pronto-scripts/bin/python/generate_canonical_states.py --check; then
    echo "   ✅ canonical-states.ts está sincronizado con el backend."
else
    echo "   ❌ Error: canonical-states.ts de Frontend está desactualizado respecto al Backend."
    EXIT_CODE=1
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "👨‍💻 [CONTRACT GUARDIAN] Visto Bueno (VoBo) ✅"
else
    echo "👨‍💻 [CONTRACT GUARDIAN] Rechazado ❌"
fi

exit $EXIT_CODE
