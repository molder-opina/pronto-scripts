#!/usr/bin/env bash
set -e

echo "💰 [AGENTE CAJERO] Validando módulo de caja y pagos (/cashier)..."

EXIT_CODE=0

# 1. Check for Cashier Section template
if [ ! -f "pronto-employees/src/pronto_employees/templates/includes/_cashier_section.html" ]; then
    echo "   ❌ Error: No se encuentra el template _cashier_section.html"
    EXIT_CODE=1
fi

# 2. Check for payment providers
if [ ! -d "pronto-libs/src/pronto_shared/services/payment_providers" ]; then
    echo "   ⚠️  Advertencia: No se detectó el directorio de proveedores de pago."
fi

# 3. Check for currency formatting in payments
if ! grep -r "formatCurrency" pronto-static/src/vue/employees/modules/sessions-manager.ts > /dev/null; then
    echo "   ⚠️  Advertencia: El gestor de sesiones no parece usar formatCurrency."
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "💰 [AGENTE CAJERO] Visto Bueno (VoBo) ✅"
else
    echo "💰 [AGENTE CAJERO] Rechazado ❌"
fi

exit $EXIT_CODE
