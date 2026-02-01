#!/bin/bash
# Script para probar todas las funcionalidades de Mesero y Cocina

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/lib/docker_runtime.sh
source "${SCRIPT_DIR}/../lib/docker_runtime.sh"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración
PORT=${EMPLOYEES_PORT:-6081}
HOST="http://localhost:${PORT}"

echo "════════════════════════════════════════════════════════════════════"
echo "  PRUEBA COMPLETA - FLUJO DE MESERO Y COCINA"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# Variables globales
WAITER_ID=""
CHEF_ID=""
ORDER_ID=""
# shellcheck disable=SC2034  # Placeholder for future use
SESSION_ID=""
COOKIES_FILE="/tmp/pronto_test_cookies_$$.txt"

# Función para limpiar
cleanup() {
    rm -f "$COOKIES_FILE"
}
trap cleanup EXIT

# Función para hacer requests
api_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local show_output=${4:-true}

    if [ "$method" = "POST" ]; then
        response=$(curl -s -L -c "$COOKIES_FILE" -b "$COOKIES_FILE" \
            -X POST \
            -H "Content-Type: application/json" \
            -d "$data" \
            "${HOST}${endpoint}" \
            -w "\nHTTP_CODE:%{http_code}")
    else
        response=$(curl -s -L -c "$COOKIES_FILE" -b "$COOKIES_FILE" \
            "${HOST}${endpoint}" \
            -w "\nHTTP_CODE:%{http_code}")
    fi

    HTTP_CODE=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    BODY=$(echo "$response" | sed '/HTTP_CODE:/d')

    if [ "$show_output" = "true" ]; then
        echo "   HTTP: $HTTP_CODE"
        echo "   Response: $(echo "$BODY" | head -c 200)"
    fi

    echo "$BODY"
}

# Función para extraer JSON
extract_json() {
    local json=$1
    local key=$2
    echo "$json" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('$key', ''))" 2>/dev/null || echo ""
}

echo ""
echo -e "${CYAN}═══ PASO 1: OBTENER IDs DE EMPLEADOS ═══${NC}"
echo ""
echo "Obteniendo lista de meseros..."
WAITERS=$(api_request "GET" "/api/employees?role=waiter" "" false)
WAITER_ID=$(echo "$WAITERS" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('employees', [{}])[0].get('id', ''))" 2>/dev/null)

echo "Obteniendo lista de chefs..."
CHEFS=$(api_request "GET" "/api/employees?role=chef" "" false)
CHEF_ID=$(echo "$CHEFS" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('employees', [{}])[0].get('id', ''))" 2>/dev/null)

if [ -z "$WAITER_ID" ] || [ -z "$CHEF_ID" ]; then
    echo -e "${RED}❌ No se encontraron empleados (Waiter ID: $WAITER_ID, Chef ID: $CHEF_ID)${NC}"
    echo "   Ejecuta el seed: ./bin/validate-seed.sh"
    exit 1
fi

echo -e "${GREEN}✓ Waiter ID: $WAITER_ID${NC}"
echo -e "${GREEN}✓ Chef ID: $CHEF_ID${NC}"

echo ""
echo -e "${CYAN}═══ PASO 2: OBTENER ÓRDENES DISPONIBLES ═══${NC}"
echo ""
ORDERS=$(api_request "GET" "/api/orders" "" false)
echo "$ORDERS" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    orders = data.get('orders', [])
    print(f'Total órdenes: {len(orders)}')
    for order in orders[:5]:
        print(f'  - Orden #{order[\"id\"]}: Estado={order[\"workflow_status\"]}, Total={order[\"total_amount\"]}')
except:
    print('Error al parsear órdenes')
" 2>/dev/null

# Buscar una orden en estado 'requested' o 'pending'
ORDER_ID=$(echo "$ORDERS" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    orders = data.get('orders', [])
    for order in orders:
        if order.get('workflow_status') in ['requested', 'pending']:
            print(order['id'])
            break
except:
    pass
" 2>/dev/null)

if [ -z "$ORDER_ID" ]; then
    echo -e "${YELLOW}⚠️  No se encontró orden en estado 'requested' o 'pending'${NC}"
    echo "   Para probar el flujo completo, necesitas crear una orden desde la app de clientes"
    echo ""
    echo -e "${BLUE}═══ PRUEBA LIMITADA - Verificando endpoints ═══${NC}"
    echo ""

    # Probar con la primera orden disponible
    ORDER_ID=$(echo "$ORDERS" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    orders = data.get('orders', [])
    if orders:
        print(orders[0]['id'])
except:
    pass
" 2>/dev/null)

    if [ -z "$ORDER_ID" ]; then
        echo -e "${RED}❌ No hay órdenes en el sistema${NC}"
        exit 1
    fi

    echo "Usando orden #$ORDER_ID para pruebas..."
else
    echo -e "${GREEN}✓ Orden encontrada: #$ORDER_ID${NC}"
fi

echo ""
echo -e "${CYAN}═══ PASO 3: FLUJO DEL MESERO ═══${NC}"
echo ""

echo "3.1. Mesero ACEPTA la orden..."
RESPONSE=$(api_request "POST" "/api/orders/${ORDER_ID}/accept" "{\"employee_id\": $WAITER_ID}")
STATUS=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('workflow_status', 'error'))" 2>/dev/null)

if [ "$STATUS" = "confirmed" ]; then
    echo -e "${GREEN}✓ Orden aceptada correctamente. Estado: $STATUS${NC}"
else
    echo -e "${YELLOW}⚠️  Estado actual: $STATUS (puede que ya estaba aceptada)${NC}"
fi

echo ""
echo -e "${CYAN}═══ PASO 4: FLUJO DE COCINA ═══${NC}"
echo ""

echo "4.1. Chef INICIA preparación..."
RESPONSE=$(api_request "POST" "/api/orders/${ORDER_ID}/kitchen/start" "{\"employee_id\": $CHEF_ID}")
STATUS=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('workflow_status', 'error'))" 2>/dev/null)

if [ "$STATUS" = "in_kitchen" ]; then
    echo -e "${GREEN}✓ Preparación iniciada. Estado: $STATUS${NC}"
else
    echo -e "${YELLOW}⚠️  Estado actual: $STATUS${NC}"
fi

echo ""
echo "4.2. Chef marca como LISTO..."
RESPONSE=$(api_request "POST" "/api/orders/${ORDER_ID}/kitchen/ready" "{}")
STATUS=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('workflow_status', 'error'))" 2>/dev/null)

if [ "$STATUS" = "ready" ]; then
    echo -e "${GREEN}✓ Orden lista. Estado: $STATUS${NC}"
else
    echo -e "${YELLOW}⚠️  Estado actual: $STATUS${NC}"
fi

echo ""
echo -e "${CYAN}═══ PASO 5: ENTREGA FINAL DEL MESERO ═══${NC}"
echo ""

echo "5.1. Mesero ENTREGA la orden..."
RESPONSE=$(api_request "POST" "/api/orders/${ORDER_ID}/deliver" "{\"employee_id\": $WAITER_ID}")
STATUS=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('workflow_status', 'error'))" 2>/dev/null)

if [ "$STATUS" = "delivered" ]; then
    echo -e "${GREEN}✓ Orden entregada. Estado: $STATUS${NC}"
else
    echo -e "${YELLOW}⚠️  Estado actual: $STATUS${NC}"
fi

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo -e "${CYAN}  RESUMEN DEL FLUJO COMPLETO${NC}"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "Flujo ideal de una orden:"
echo ""
echo "  1. Cliente crea orden          → workflow_status: 'requested'"
echo "  2. ✓ Mesero acepta             → workflow_status: 'confirmed'"
echo "  3. ✓ Chef inicia preparación   → workflow_status: 'in_kitchen'"
echo "  4. ✓ Chef marca como listo     → workflow_status: 'ready'"
echo "  5. ✓ Mesero entrega            → workflow_status: 'delivered'"
echo ""
echo "Endpoints probados:"
echo "  ✓ POST /api/orders/{id}/accept         (Mesero acepta)"
echo "  ✓ POST /api/orders/{id}/kitchen/start  (Chef inicia)"
echo "  ✓ POST /api/orders/{id}/kitchen/ready  (Chef completa)"
echo "  ✓ POST /api/orders/{id}/deliver        (Mesero entrega)"
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "Para ver las interfaces:"
echo "  - Panel de meseros: ${HOST}/waiter"
echo "  - Panel de cocina:  ${HOST}/kitchen"
echo ""
echo "Para ver en tiempo real:"
echo "  docker-compose logs -f employees"
echo ""
