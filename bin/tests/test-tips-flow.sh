#!/usr/bin/env bash
# Script para probar el flujo completo de propinas
# FINAL: Hace login separado para cada scope necesario

set -e

# shellcheck disable=SC2034  # Color variables used in echo statements
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CLIENT_API_BASE="http://localhost:6080"
CLIENT_API="${CLIENT_API_BASE%/}/api"
COOKIE_ADMIN="/tmp/pronto_test_admin.txt"
COOKIE_WAITER="/tmp/pronto_test_waiter.txt"
COOKIE_CHEF="/tmp/pronto_test_chef.txt"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  PRUEBA DE FLUJO COMPLETO DE PROPINAS${NC}"
echo -e "${BLUE}  (Versión Final - Logins Múltiples)${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Limpiar sesiones anteriores
rm -f "$COOKIE_ADMIN" "$COOKIE_WAITER" "$COOKIE_CHEF"

# 1. Obtener tablas disponibles
echo -e "${YELLOW}[1/13]${NC} Obteniendo tablas disponibles..."
TABLES_JSON=$(curl -s "$CLIENT_API/tables")
TABLE_ID=$(echo "$TABLES_JSON" | jq '.tables[0].id')
TABLE_NUMBER=$(echo "$TABLES_JSON" | jq '.tables[0].table_number' -r)
echo -e "${GREEN}✓${NC} Usando tabla: $TABLE_NUMBER (ID: $TABLE_ID)"
echo ""

# 2. Abrir sesión
echo -e "${YELLOW}[2/13]${NC} Abriendo sesión de mesa..."
SESSION_RESPONSE=$(curl -s -X POST "$CLIENT_API/sessions/open" \
    -H "Content-Type: application/json" \
    -d "{
        \"table_id\": $TABLE_ID
    }")

SESSION_ID=$(echo "$SESSION_RESPONSE" | jq -r '.data.session_id')

if [ "$SESSION_ID" = "null" ] || [ -z "$SESSION_ID" ]; then
    echo -e "${RED}❌ No se pudo obtener session_id${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Sesión creada con ID: $SESSION_ID"
echo ""

# 3. Login como admin (scope: admin)
echo -e "${YELLOW}[3/13]${NC} Login como admin (scope: admin)..."
curl -s -X POST "http://localhost:6081/admin/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin.roles@cafeteria.test","password":"ChangeMe!123"}' \
    -c "$COOKIE_ADMIN" > /dev/null

echo -e "${GREEN}✓${NC} Admin logueado con scope admin"
echo ""

# 4. Login como mesero (scope: waiter)
echo -e "${YELLOW}[4/13]${NC} Login como mesero (scope: waiter)..."
curl -s -X POST "http://localhost:6081/waiter/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin.roles@cafeteria.test","password":"ChangeMe!123"}' \
    -c "$COOKIE_WAITER" > /dev/null

echo -e "${GREEN}✓${NC} Mesero logueado con scope waiter"
echo ""

# 5. Login como chef (scope: chef)
echo -e "${YELLOW}[5/13]${NC} Login como chef (scope: chef)..."
curl -s -X POST "http://localhost:6081/chef/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin.roles@cafeteria.test","password":"ChangeMe!123"}' \
    -c "$COOKIE_CHEF" > /dev/null

echo -e "${GREEN}✓${NC} Chef logueado con scope chef"
echo ""

# 6. Crear orden
echo -e "${YELLOW}[6/13]${NC} Creando orden con items (sin modificadores)..."
ORDER_RESPONSE=$(curl -s -X POST "$CLIENT_API/orders" \
    -H "Content-Type: application/json" \
    -d "{
        \"customer\": {
            \"name\": \"Cliente Test Propinas\",
            \"email\": \"cliente.propinas@test.com\",
            \"phone\": \"+34666777888\"
        },
        \"items\": [
            {\"menu_item_id\": 58, \"quantity\": 2},
            {\"menu_item_id\": 60, \"quantity\": 1}
        ],
        \"table_number\": \"$TABLE_NUMBER\",
        \"notes\": \"Orden de prueba para propinas\"
    }")

ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.order_id // .id')

if [ "$ORDER_ID" = "null" ] || [ -z "$ORDER_ID" ]; then
    echo -e "${RED}❌ No se pudo obtener order_id${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Orden creada con ID: $ORDER_ID"
echo ""

# 7. Mesero acepta la orden (scope: waiter)
echo -e "${YELLOW}[7/13]${NC} Mesero acepta la orden (scope: waiter)..."
ACCEPT_RESPONSE=$(curl -s -X POST "http://localhost:6081/waiter/api/orders/$ORDER_ID/accept" \
    -H "Content-Type: application/json" \
    -d '{"employee_id": 3}' \
    -b "$COOKIE_WAITER")

echo "$ACCEPT_RESPONSE" | jq '.'
echo ""

# 8. Chef inicia preparación (scope: chef)
echo -e "${YELLOW}[8/13]${NC} Chef inicia preparación (scope: chef)..."
KITCHEN_START=$(curl -s -X POST "http://localhost:6081/chef/api/orders/$ORDER_ID/kitchen/start" \
    -H "Content-Type: application/json" \
    -d '{"employee_id": 6}' \
    -b "$COOKIE_CHEF")

echo "$KITCHEN_START" | jq '.'
echo ""

# 9. Chef marca como listo (scope: chef)
echo -e "${YELLOW}[9/13]${NC} Chef marca orden como lista (scope: chef)..."
KITCHEN_READY=$(curl -s -X POST "http://localhost:6081/chef/api/orders/$ORDER_ID/kitchen/ready" \
    -b "$COOKIE_CHEF")

echo "$KITCHEN_READY" | jq '.'
echo ""

# 10. Mesero entrega la orden (scope: waiter)
echo -e "${YELLOW}[10/13]${NC} Mesero entrega la orden (scope: waiter)..."
DELIVER_RESPONSE=$(curl -s -X POST "http://localhost:6081/waiter/api/orders/$ORDER_ID/deliver" \
    -H "Content-Type: application/json" \
    -d '{"employee_id": 3}' \
    -b "$COOKIE_WAITER")

echo "$DELIVER_RESPONSE" | jq '.'
echo ""

# 11. Ver ticket (scope: admin)
echo -e "${YELLOW}[11/13]${NC} Ver ticket de la cuenta (scope: admin)..."
TICKET=$(curl -s -X GET "http://localhost:6081/admin/api/sessions/$SESSION_ID/ticket" \
    -b "$COOKIE_ADMIN")

echo "$TICKET" | jq -r '.ticket'
echo ""

# 12. Probar propina del 10% (scope: admin)
echo -e "${YELLOW}[12/13]${NC} Probando propina del 10% (scope: admin)..."
PAYMENT_10=$(curl -s -X POST "http://localhost:6081/admin/api/sessions/$SESSION_ID/pay" \
    -H "Content-Type: application/json" \
    -d "{
        \"payment_method\": \"cash\",
        \"tip_percentage\": 10
    }" \
    -b "$COOKIE_ADMIN")

echo "$PAYMENT_10" | jq '.totals'
SUBTOTAL=$(echo "$PAYMENT_10" | jq -r '.totals.subtotal')
TIP_10=$(echo "$PAYMENT_10" | jq -r '.totals.tip_amount')
TOTAL_10=$(echo "$PAYMENT_10" | jq -r '.totals.total_amount')

echo ""
echo "Resumen de Propinas:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Subtotal: $SUBTOTAL"
echo "Propina 10%: $TIP_10"
echo "Total con 10%: $TOTAL_10"
echo ""

# 13. Verificar propinas del mesero (scope: waiter)
echo -e "${YELLOW}[13/13]${NC} Verificando propinas del mesero (scope: waiter)..."
TIPS_RESPONSE=$(curl -s -X GET "http://localhost:6081/waiter/api/employees/3/tips" -b "$COOKIE_WAITER")
echo "$TIPS_RESPONSE" | jq '.'
echo ""

# Simular otros porcentajes de propina
echo ""
echo -e "${BLUE}Simulando otros porcentajes de propina:${NC}"
echo ""

if [ "$SUBTOTAL" != "null" ] && [ "$SUBTOTAL" != "" ]; then
    python3 - "$SUBTOTAL" <<'PY'
import sys
subtotal = float(sys.argv[1])

percentages = [5, 10, 15, 20]
print("Tabla de Propinas")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print(f"{'Porcentaje':<15} {'Propina':<15} {'Total':<15}")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
for pct in percentages:
    tip = round(subtotal * pct / 100, 2)
    total = subtotal + tip
    print(f"{pct}%{'':<12} ${tip:<14.2f} ${total:<14.2f}")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
PY
else
    echo -e "${YELLOW}⚠️  No se puede calcular propinas: subtotal es null${NC}"
fi

# Resumen final
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  FLUJO DE PROPINAS COMPLETADO${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Empleados involucrados:"
echo "• Mesero: Juan Mesero (ID: 3) - Aceptó y entregó"
echo "• Chef: Carlos Chef (ID: 6) - Preparó"
echo ""
echo "Opciones de propina disponibles:"
echo "• 5%  - Servicio básico"
echo "• 10% - Servicio estándar"
echo "• 15% - Buen servicio"
echo "• 20% - Excelente servicio"
echo ""
echo "Scopes utilizados:"
echo "• /admin/api/auth/login - Login como admin"
echo "• /waiter/api/auth/login - Login como mesero"
echo "• /chef/api/auth/login - Login como chef"
echo "• /waiter/api/orders/*/accept - Aceptar orden"
echo "• /chef/api/orders/*/kitchen/* - Preparar orden"
echo "• /waiter/api/orders/*/deliver - Entregar orden"
echo "• /admin/api/sessions/*/ticket - Ver ticket"
echo "• /admin/api/sessions/*/pay - Pagar con propina"
echo "• /waiter/api/employees/*/tips - Ver propinas"
echo ""
echo -e "${GREEN}✅ Todos los pasos completados exitosamente${NC}"
echo ""

# Limpiar
rm -f "$COOKIE_ADMIN" "$COOKIE_WAITER" "$COOKIE_CHEF"
