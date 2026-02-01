#!/usr/bin/env bash
set -e

echo "🎨 [AGENTE DISEÑADOR] Revisando activos visuales y estilos..."

EXIT_CODE=0

# 1. Check for large images (>1MB)
echo "   - Verificando tamaño de imágenes..."
LARGE_IMAGES=$(find src/static_content/assets -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -size +1M)
if [ -n "$LARGE_IMAGES" ]; then
    echo "   ⚠️  Advertencia: Imágenes mayores a 1MB detectadas:"
    echo "$LARGE_IMAGES" | head -n 3
    # Just warn for now
else
    echo "   ✅ Imágenes optimizadas."
fi

# 2. Check for CSS !important overuse
echo "   - Verificando uso de !important en CSS..."
IMPORTANT_COUNT=$(grep -r "!important" src/ --include="*.css" | wc -l)
if [ "$IMPORTANT_COUNT" -gt 10 ]; then
    echo "   ⚠️  Advertencia: Uso excesivo de !important ($IMPORTANT_COUNT ocurrencias)."
else
    echo "   ✅ Uso de !important bajo control."
fi

# 3. Check for empty alt tags
echo "   - Buscando atributos alt vacíos..."
if grep -r 'alt=""' src/ --include="*.html" --include="*.vue" > /dev/null; then
    echo "   ⚠️  Advertencia: Imágenes sin texto alternativo (alt=\"\") encontradas."
else
    echo "   ✅ Accesibilidad de imágenes básica correcta."
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "👩‍🎨 [AGENTE DISEÑADOR] Visto Bueno (VoBo) ✅"
else
    echo "👩‍🎨 [AGENTE DISEÑADOR] Rechazado ❌"
fi

exit $EXIT_CODE
