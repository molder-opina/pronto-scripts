#!/usr/bin/env bash
# Script para verificar si los datos de prueba se cargaron correctamente

set -euo pipefail

EMPLOYEE_API_BASE="${EMPLOYEE_API_BASE_URL:-http://localhost:${EMPLOYEE_APP_HOST_PORT:-6081}}"
if [[ "$EMPLOYEE_API_BASE" == */api ]]; then
  API_BASE="${EMPLOYEE_API_BASE%/}"
else
  API_BASE="${EMPLOYEE_API_BASE%/}/api"
fi

echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║     🔍 VERIFICANDO ESTADO DE DATOS DE PRUEBA         ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

echo "1️⃣  Verificando que la API de empleados esté activa..."
if ! curl -sf "${API_BASE}/health" >/dev/null 2>&1; then
    echo "❌ La API no está respondiendo en ${API_BASE}"
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
categories = data.get("categories") or []
item_count = sum(len(category.get("items") or []) for category in categories)
print(item_count)
print(len(categories))
for category in categories:
    name = category.get("name") or ""
    if name:
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
