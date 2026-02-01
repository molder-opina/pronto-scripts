#!/usr/bin/env bash
set -e

echo "👨‍🍳 [AGENTE CHEF] Validando consola de cocina (/chef)..."

EXIT_CODE=0

# 1. Check for Chef Section template
if [ ! -f "src/employees_app/templates/includes/_chef_section.html" ]; then
    echo "   ❌ Error: No se encuentra el template _chef_section.html"
    EXIT_CODE=1
fi

# 2. Check for Kitchen JS module
if [ ! -f "src/shared/static/js/src/modules/kitchen-board.ts" ]; then
    echo "   ⚠️  Advertencia: No se encuentra el módulo de cocina (kitchen-board.ts)"
fi

# 3. Check for order status transitions related to kitchen
if ! grep -r "preparing" src/shared/constants.py > /dev/null; then
    echo "   ❌ Error: El estado 'preparing' no está definido en las constantes."
    EXIT_CODE=1
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "👨‍🍳 [AGENTE CHEF] Visto Bueno (VoBo) ✅"
else
    echo "👨‍🍳 [AGENTE CHEF] Rechazado ❌"
fi

exit $EXIT_CODE
