#!/usr/bin/env bash
set -e

echo "🤵 [AGENTE MESERO] Validando consola de meseros (/waiter)..."

EXIT_CODE=0

# 1. Check for Waiter Section template
if [ ! -f "src/employees_app/templates/includes/_waiter_section.html" ]; then
    echo "   ❌ Error: No se encuentra el template _waiter_section.html"
    EXIT_CODE=1
fi

# 2. Check for Waiter JS module
if [ ! -f "src/shared/static/js/src/modules/waiter-board.ts" ]; then
    echo "   ⚠️  Advertencia: No se encuentra el módulo principal de meseros (waiter-board.ts)"
fi

# 3. Check for waiter assignment logic
if ! grep -r "table-assignment" src/employees_app/static/js/src > /dev/null; then
    echo "   ⚠️  Advertencia: No se detectó lógica de asignación de mesas."
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "🤵 [AGENTE MESERO] Visto Bueno (VoBo) ✅"
else
    echo "🤵 [AGENTE MESERO] Rechazado ❌"
fi

exit $EXIT_CODE
