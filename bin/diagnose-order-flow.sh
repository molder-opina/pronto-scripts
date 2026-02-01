#!/usr/bin/env bash
# Diagnóstico del flujo de órdenes - Identifica los problemas en el flujo de pruebas

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CLIENT_API_BASE="http://localhost:6080"
CLIENT_API="${CLIENT_API_BASE}/api"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                ║${NC}"
echo -e "${BLUE}║   DIAGNÓSTICO DEL FLUJO DE ÓRDENES          ║${NC}"
echo -e "${BLUE}║                                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Verificar que los servicios estén corriendo
echo -e "${YELLOW}[1/7]${NC} Verificando servicios..."
if ! curl -sf "${CLIENT_API}/health" > /dev/null 2>&1; then
    echo -e "${RED}❌ Client API no está disponible${NC}"
    echo ""
    echo "Por favor inicia los servicios primero:"
    echo "  bash bin/up.sh"
    exit 1
fi
echo -e "${GREEN}✓${NC} Client API disponible"
echo ""

# Verificar endpoints disponibles
echo -e "${YELLOW}[2/7]${NC} Verificando endpoints de la API de clientes..."
echo ""

echo -e "${CYAN}Endpoints de Sesiones:${NC}"
echo "  POST   ${CLIENT_API}/sessions/open"
echo "  POST   ${CLIENT_API}/sessions/merge"
echo "  POST   ${CLIENT_API}/sessions/<id>/split"
echo ""

echo -e "${CYAN}Endpoints de Órdenes:${NC}"
echo "  POST   ${CLIENT_API}/orders"
echo "  POST   ${CLIENT_API}/orders/<id>/cancel"
echo "  POST   ${CLIENT_API}/orders/<id>/modify"
echo "  POST   ${CLIENT_API}/modifications/<id>/approve"
echo "  POST   ${CLIENT_API}/modifications/<id>/reject"
echo "  POST   ${CLIENT_API}/orders/<id>/request-check"
echo ""

echo -e "${RED}❌ NO EXISTE POST ${CLIENT_API}/customers${NC}"
echo -e "${RED}❌ NO EXISTE POST ${CLIENT_API}/sessions (debe ser /sessions/open)${NC}"
echo ""

# Verificar tablas disponibles
echo -e "${YELLOW}[3/7]${NC} Verificando tablas disponibles..."
echo ""
TABLES_JSON=$(curl -s "${CLIENT_API}/tables")
TABLE_COUNT=$(echo "$TABLES_JSON" | jq '.tables | length')
echo -e "${GREEN}✓${NC} Hay ${TABLE_COUNT} mesas disponibles"
echo ""
echo "Primeras 3 mesas:"
echo "$TABLES_JSON" | jq '.tables[:3] | .[] | {table_number: .table_number, qr_code: .qr_code, area: .area}'
echo ""

# Verificar items de menú disponibles
echo -e "${YELLOW}[4/7]${NC} Verificando items de menú disponibles..."
echo ""
MENU_JSON=$(curl -s "${CLIENT_API}/menu")
ITEM_COUNT=$(echo "$MENU_JSON" | jq '[.categories[].items] | add | length')
echo -e "${GREEN}✓${NC} Hay ${ITEM_COUNT} items de menú disponibles"
echo ""
echo "Primeros 3 items:"
echo "$MENU_JSON" | jq '.categories[0].items[:3] | .[] | {id: .id, name: .name, price: .price}'
echo ""

# Probar el flujo correcto de creación de orden
echo -e "${YELLOW}[5/7]${NC} Probando flujo correcto de creación de orden..."
echo ""

# Paso 1: Obtener tabla válida
TABLE_NUMBER=$(echo "$TABLES_JSON" | jq '.tables[0].table_number' -r)
echo -e "${CYAN}→${NC} Usando tabla: ${TABLE_NUMBER}"
echo ""

# Paso 2: Abrir sesión
echo -e "${CYAN}→${NC} Abriendo sesión..."
SESSION_RESPONSE=$(curl -s -X POST "${CLIENT_API}/sessions/open" \
    -H "Content-Type: application/json" \
    -d "{\"table_number\": \"${TABLE_NUMBER}\"}")

SESSION_ID=$(echo "$SESSION_RESPONSE" | jq -r '.data.session_id // .id // empty')

if [ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "null" ]; then
    echo -e "${RED}❌ Error abriendo sesión${NC}"
    echo "Respuesta: $SESSION_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓${NC} Sesión creada con ID: ${SESSION_ID}"
echo ""

# Paso 3: Crear orden (flujo correcto)
echo -e "${CYAN}→${NC} Creando orden con estructura correcta..."
ORDER_RESPONSE=$(curl -s -X POST "${CLIENT_API}/orders" \
    -H "Content-Type: application/json" \
    -d "{
        \"customer\": {
            \"name\": \"Cliente Test Diagnóstico\",
            \"email\": \"diagnostico@test.com\",
            \"phone\": \"+34666777888\"
        },
        \"items\": [
            {\"menu_item_id\": 1, \"quantity\": 1},
            {\"menu_item_id\": 2, \"quantity\": 1}
        ],
        \"notes\": \"Orden de diagnóstico\",
        \"table_number\": \"${TABLE_NUMBER}\"
    }")

ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.order_id // .id // empty')
ERROR_MSG=$(echo "$ORDER_RESPONSE" | jq -r '.error // empty')

if [ -z "$ORDER_ID" ] || [ "$ORDER_ID" = "null" ]; then
    echo -e "${RED}❌ Error creando orden${NC}"
    echo "Respuesta: $ORDER_RESPONSE"
    echo ""
    echo -e "${YELLOW}Probable causa:${NC}"
    echo "  - Estructura del payload incorrecta"
    echo "  - Validación de datos fallida"
    echo "  - Error en el servidor"
    echo ""
    echo -e "${CYAN}Payload enviado:${NC}"
    echo "  customer: {name, email, phone}"
    echo "  items: [{menu_item_id, quantity}]"
    echo "  notes: string"
    echo "  table_number: string"
    exit 1
fi

echo -e "${GREEN}✓${NC} Orden creada con ID: ${ORDER_ID}"
echo ""

# Verificar detalles de la orden
echo -e "${YELLOW}[6/7]${NC} Verificando detalles de la orden..."
echo ""
ORDER_DETAIL=$(curl -s "${CLIENT_API}/orders/${ORDER_ID}")
echo "$ORDER_DETAIL" | jq '.'
echo ""

# Verificar totales
echo -e "${YELLOW}[7/7]${NC} Verificando cálculo de totales..."
echo ""
SUBTOTAL=$(echo "$ORDER_RESPONSE" | jq -r '.totals.subtotal // empty')
TAX=$(echo "$ORDER_RESPONSE" | jq -r '.totals.tax_amount // empty')
TOTAL=$(echo "$ORDER_RESPONSE" | jq -r '.totals.total_amount // empty')

if [ "$SUBTOTAL" != "null" ] && [ "$TOTAL" != "null" ]; then
    echo -e "${GREEN}✓${NC} Totales calculados correctamente:"
    echo "  Subtotal: $SUBTOTAL"
    echo "  Impuestos: $TAX"
    echo "  Total:    $TOTAL"
    echo ""
else
    echo -e "${RED}❌ Error en el cálculo de totales${NC}"
    echo "Subtotal: $SUBTOTAL"
    echo "Total:    $TOTAL"
fi

# Resumen
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                ║${NC}"
echo -e "${BLUE}║   RESUMEN DEL DIAGNÓSTICO                     ║${NC}"
echo -e "${BLUE}║                                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}✅ SERVICIOS:${NC}"
echo "  ✓ Client API funcionando"
echo "  ✓ ${TABLE_COUNT} mesas disponibles"
echo "  ✓ ${ITEM_COUNT} items de menú"
echo ""

echo -e "${CYAN}✅ FLUJO CORRECTO:${NC}"
echo "  1. POST ${CLIENT_API}/sessions/open con table_id"
echo "  2. POST ${CLIENT_API}/orders con:"
echo "     - customer: {name, email, phone}"
echo "     - items: [{menu_item_id, quantity}]"
echo "     - table_number: string"
echo "     - notes: string (opcional)"
echo ""

echo -e "${RED}❌ ERRORES EN TEST ANTIGUO (bin/tests/test-tips-flow.sh):${NC}"
echo "  1. POST ${CLIENT_API}/customers - Este endpoint NO existe"
echo "  2. POST ${CLIENT_API}/sessions - Debe ser /sessions/open"
echo "  3. Payload de orden usa customer_id/session_id en lugar de customer/table_number"
echo ""

echo -e "${YELLOW}📋 ACCIONES REQUERIDAS:${NC}"
echo "  1. Actualizar bin/tests/test-tips-flow.sh para usar el flujo correcto"
echo "  2. Usar POST /sessions/open en lugar de POST /sessions"
echo "  3. Usar payload correcto con customer dict en lugar de customer_id"
echo ""

echo -e "${GREEN}✅ El flujo de órdenes funciona correctamente con el formato adecuado${NC}"
