#!/usr/bin/env bash
set -e

echo "🍽️  [AGENTE EXPERTO NEGOCIO] Validando reglas de negocio restaurantero..."

EXIT_CODE=0

# 1. Check for key business terminology (Spanish)
# This ensures we are using the correct domain language
echo "   - Verificando terminología de negocio..."
REQUIRED_TERMS=("propina" "mesa" "orden" "comanda" "caja" "corte")
MISSING_TERMS=0

# We search in the whole build directory but exclude binary files and dist
for term in "${REQUIRED_TERMS[@]}"; do
    if ! grep -rI "$term" src/ --exclude-dir="dist" --exclude-dir="__pycache__" > /dev/null; then
        echo "   ⚠️  Advertencia: No se encontró el término crítico de negocio '$term'. ¿Está completa la lógica de negocio?"
        MISSING_TERMS=$((MISSING_TERMS + 1))
    fi
done

if [ "$MISSING_TERMS" -eq 0 ]; then
    echo "   ✅ Terminología de negocio presente."
fi

# 2. Check for Currency Formatting usage
echo "   - Verificando uso de formateo de moneda..."
# Look for 'formatCurrency' usage in frontend code
if ! grep -r "formatCurrency" src/pronto_clients/static/js/src > /dev/null && ! grep -r "formatCurrency" src/pronto_employees/static/js/src > /dev/null; then
    echo "   ⚠️  Advertencia: No se detectó uso de 'formatCurrency' en el frontend. Verifica que los precios se muestren correctamente."
else
    echo "   ✅ Función de formateo de moneda en uso."
fi

# 3. Verify Business Config seed presence
echo "   - Verificando configuración inicial de negocio..."
if [ ! -f "src/shared/services/business_config_service.py" ]; then
    echo "   ❌ Error: Falta el servicio de configuración de negocio (business_config_service.py)."
    EXIT_CODE=1
else
    echo "   ✅ Servicio de configuración de negocio detectado."
fi

# 4. Check for Tip Calculation logic
echo "   - Buscando lógica de cálculo de propinas..."
if ! grep -r "tip" src/ --include="*.py" --include="*.ts" > /dev/null; then
    echo "   ⚠️  Advertencia: No se encontró lógica relacionada con 'tip' (propina). Es crítica para la operación."
else
    echo "   ✅ Lógica de propinas detectada."
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "🍽️  [AGENTE EXPERTO NEGOCIO] Visto Bueno (VoBo) ✅"
else
    echo "🍽️  [AGENTE EXPERTO NEGOCIO] Rechazado ❌"
fi

exit $EXIT_CODE
