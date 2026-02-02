#!/usr/bin/env bash
set -e

echo "🧪 [AGENTE QA/TESTER] Verificando integridad de pruebas..."

EXIT_CODE=0

# 1. Check for focused tests (which skip others)
echo "   - Buscando pruebas enfocadas (.only, fit)..."
if grep -rE "\.only\(|fit\(|fdescribe\(" tests/ e2e-tests/ pronto-static/src/ pronto-client/src/ pronto-employees/src/ --include="*.ts" --include="*.js" --include="*.py" --exclude-dir=node_modules > /dev/null 2>&1; then
    echo "   ❌ Error: Se encontraron pruebas enfocadas (.only, fit, fdescribe). Esto evita que corran todas las pruebas."
    grep -rE "\.only\(|fit\(|fdescribe\(" tests/ e2e-tests/ --include="*.ts" --include="*.js" --include="*.py" --exclude-dir=node_modules | head -n 3
    EXIT_CODE=1
else
    echo "   ✅ No hay pruebas enfocadas (se correrá la suite completa)."
fi

# 2. Check if pytest markers are registered (optional but good)
# echo "   - Verificando marcadores de pytest..."
# if grep -r "@pytest.mark." tests/ --include="*.py" | grep -vE "asyncio|parametrize|skip|xfail" > /dev/null; then
#    # Logic to check against pytest.ini could go here
#    true
# fi

# 3. Warn if large number of tests changed but snapshots not updated (heuristic)
# This is hard to do without git context, skipping for now.

if [ $EXIT_CODE -eq 0 ]; then
    echo "🕵️  [AGENTE QA/TESTER] Visto Bueno (VoBo) ✅"
else
    echo "🕵️  [AGENTE QA/TESTER] Rechazado ❌"
fi

exit $EXIT_CODE
