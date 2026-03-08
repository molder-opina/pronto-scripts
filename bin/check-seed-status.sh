#!/usr/bin/env bash
# Script para verificar si los datos de prueba se cargaron correctamente

set -euo pipefail

CANONICAL_API_BASE="${PRONTO_API_URL:-http://localhost:6082}"
if [[ "$CANONICAL_API_BASE" == */api ]]; then
  API_BASE="${CANONICAL_API_BASE%/}"
else
  API_BASE="${CANONICAL_API_BASE%/}/api"
fi
HEALTH_BASE="${API_BASE%/api}"

echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║     🔍 VERIFICANDO ESTADO DE DATOS DE PRUEBA         ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

echo "1️⃣  Verificando que la API canónica esté activa..."
if ! curl -sf "${HEALTH_BASE}/health" >/dev/null 2>&1; then
    echo "❌ La API no está respondiendo en ${HEALTH_BASE}/health"
    echo "💡 Solución: Ejecuta uno de estos comandos:"
    echo "   bash bin/up-debug.sh --seed"
    echo "   bash bin/rebuild.sh --seed"
    exit 1
fi
echo "✅ API activa"
echo ""

if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ python3 no está disponible para parsear el menú."
    exit 1
fi

echo "2️⃣  Obteniendo menú desde la API..."
menu_payload=$(curl -sf "${API_BASE}/menu" 2>/dev/null) || {
    echo "❌ No se pudo obtener /api/menu"
    exit 1
}

menu_summary=$(printf '%s' "$menu_payload" | python3 -c 'import json
import sys

data = json.load(sys.stdin)
payload = data.get("data") if isinstance(data, dict) else None
payload = payload if isinstance(payload, dict) else data

catalog_items = payload.get("catalog_items") or [] if isinstance(payload, dict) else []
if catalog_items:
    item_count = len(catalog_items)
    category_names = sorted(
        {
            item.get("menu_category_name") or ""
            for item in catalog_items
            if item.get("menu_category_name")
        }
    )
else:
    categories = payload.get("categories") or [] if isinstance(payload, dict) else []
    item_count = sum(len(category.get("items") or []) for category in categories)
    category_names = [category.get("name") or "" for category in categories if category.get("name")]

print(item_count)
print(len(category_names))
for name in category_names:
    print(name)
')

PRODUCT_COUNT=$(echo "$menu_summary" | sed -n '1p')
CATEGORY_COUNT=$(echo "$menu_summary" | sed -n '2p')
CATEGORY_LIST=$(echo "$menu_summary" | sed '1,2d')

if [ "$PRODUCT_COUNT" = "0" ]; then
    echo "❌ No se encontraron productos en la API"
    echo ""
    echo "💡 Solución: Ejecuta uno de estos comandos:"
    echo "   bash bin/up-debug.sh --seed"
    echo "   bash bin/rebuild.sh --seed"
    exit 1
fi

echo "✅ Productos encontrados: $PRODUCT_COUNT"
echo ""

echo "3️⃣  Contando categorías..."
echo "✅ Categorías encontradas: $CATEGORY_COUNT"
echo ""

# Mostrar algunas categorías
echo "4️⃣  Mostrando categorías disponibles:"
if [[ -n "${CATEGORY_LIST}" ]]; then
    echo "${CATEGORY_LIST}"
else
    echo "(sin categorías)"
fi
echo ""

# Resumen final
echo "╔═══════════════════════════════════════════════════════╗"
echo "║                   RESUMEN                             ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

if [ "$PRODUCT_COUNT" -ge "90" ]; then
    echo "✅ ¡PERFECTO! Se cargaron los datos de prueba correctamente"
    echo "   📦 $PRODUCT_COUNT productos"
    echo "   📂 $CATEGORY_COUNT categorías"
    echo ""
    echo "🌐 Accede a:"
    echo "   • Cliente: http://localhost:6080"
    echo "   • Empleados: http://localhost:6081"
elif [ "$PRODUCT_COUNT" -gt "0" ] && [ "$PRODUCT_COUNT" -lt "90" ]; then
    echo "⚠️  Datos parciales encontrados"
    echo "   Se esperaban ~94 productos pero se encontraron $PRODUCT_COUNT"
    echo ""
    echo "💡 Ejecuta para cargar/actualizar todos los datos:"
    echo "   bash bin/up-debug.sh --seed"
else
    echo "❌ No se encontraron datos de prueba"
    echo ""
    echo "💡 Ejecuta para cargar los datos:"
    echo "   bash bin/up-debug.sh --seed"
fi

echo ""
