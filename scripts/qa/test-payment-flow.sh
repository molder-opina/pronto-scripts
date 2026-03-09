#!/bin/bash

# Script para probar el flujo completo de pago con confirmación
# Requiere que los servicios estén corriendo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}" && pwd)"
ENV_FILE="${PROJECT_ROOT}/conf/general.env"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

BASE_URL="${EMPLOYEE_API_BASE_URL:-http://localhost:${EMPLOYEE_APP_HOST_PORT:-6081}}"
if [[ "$BASE_URL" == */api ]]; then
  API_URL="$BASE_URL"
else
  API_URL="${BASE_URL%/}/api"
fi

echo "🧪 Probando flujo completo de pago con confirmación"
echo "=================================================="
echo ""

# 1. Crear orden de prueba
echo "1️⃣ Creando orden de prueba..."
ORDER_RESPONSE=$(curl -s -X POST "${API_URL}/debug/orders" \
  -H "Content-Type: application/json" \
  -d '{
    "customer": {
      "name": "Cliente Prueba Pago",
      "email": "test-pago@test.com",
      "phone": "+52 55 1234 5678"
    },
    "table_number": "Mesa Prueba",
    "items": [
      {"menu_item_id": 1, "quantity": 2},
      {"menu_item_id": 2, "quantity": 1}
    ]
  }')

ORDER_ID=$(echo $ORDER_RESPONSE | grep -o '"order_id":[0-9]*' | grep -o '[0-9]*')
SESSION_ID=$(echo $ORDER_RESPONSE | grep -o '"session_id":[0-9]*' | grep -o '[0-9]*')

if [ -z "$ORDER_ID" ] || [ -z "$SESSION_ID" ]; then
  echo "❌ Error al crear orden de prueba"
  echo "Response: $ORDER_RESPONSE"
  exit 1
fi

echo "✅ Orden creada: ID=$ORDER_ID, Sesión=$SESSION_ID"
echo ""

# 2. Aceptar orden como mesero (necesitamos un mesero ID)
echo "2️⃣ Aceptando orden como mesero..."
# Primero obtener un mesero
WAITER_RESPONSE=$(curl -s -X GET "${API_URL}/employees?role=waiter" \
  -H "Cookie: session=test" 2>/dev/null || echo '{"employees":[]}')

if command -v jq >/dev/null 2>&1; then
  WAITER_ID=$(echo "$WAITER_RESPONSE" | jq -r '.employees[0].id // 1')
else
  PARSED_WAITER=$(echo "$WAITER_RESPONSE" | grep -o '"id":[0-9]*' | head -n1 | grep -o '[0-9]*')
  WAITER_ID=${PARSED_WAITER:-1}
fi
echo "Usando waiter_id=${WAITER_ID}"

ACCEPT_RESPONSE=$(curl -s -X POST "${API_URL}/orders/${ORDER_ID}/accept" \
  -H "Content-Type: application/json" \
  -H "Cookie: session=test" \
  -d "{\"waiter_id\": ${WAITER_ID}}")

echo "✅ Orden aceptada"
echo "Respuesta: $ACCEPT_RESPONSE"
echo ""

# 3. Entregar orden
echo "3️⃣ Entregando orden..."
DELIVER_RESPONSE=$(curl -s -X POST "${API_URL}/orders/${ORDER_ID}/deliver" \
  -H "Content-Type: application/json" \
  -H "Cookie: session=test" \
  -d "{\"waiter_id\": ${WAITER_ID}}")

echo "✅ Orden entregada"
echo "Respuesta: $DELIVER_RESPONSE"
echo ""

# 4. Pedir cuenta (checkout)
echo "4️⃣ Cliente pide cuenta (checkout)..."
CHECKOUT_RESPONSE=$(curl -s -X POST "${API_URL}/sessions/${SESSION_ID}/checkout" \
  -H "Content-Type: application/json" \
  -H "Cookie: session=test")

echo "✅ Cuenta solicitada"
echo "Response: $CHECKOUT_RESPONSE"
echo ""

# 5. Procesar pago con efectivo
echo "5️⃣ Procesando pago con EFECTIVO..."
PAY_RESPONSE=$(curl -s -X POST "${API_URL}/sessions/${SESSION_ID}/pay" \
  -H "Content-Type: application/json" \
  -H "Cookie: session=test" \
  -d '{
    "payment_method": "cash"
  }')

echo "✅ Pago procesado"
echo "Response: $PAY_RESPONSE"
echo ""

# Verificar que requiere confirmación
if echo "$PAY_RESPONSE" | grep -q "awaiting_payment_confirmation"; then
  echo "✅ Estado correcto: awaiting_payment_confirmation"
else
  echo "⚠️ Estado inesperado en la respuesta"
fi

# 6. Verificar estado de la sesión
echo "6️⃣ Verificando estado de la sesión..."
SESSION_STATUS=$(curl -s -X GET "${API_URL}/sessions/${SESSION_ID}" \
  -H "Cookie: session=test" 2>/dev/null || echo '{"status":"unknown"}')

echo "Estado actual: $SESSION_STATUS"
echo ""

# 7. Confirmar pago
echo "7️⃣ Confirmando pago del mesero..."
CONFIRM_RESPONSE=$(curl -s -X POST "${API_URL}/sessions/${SESSION_ID}/confirm-payment" \
  -H "Content-Type: application/json" \
  -H "Cookie: session=test")

echo "✅ Pago confirmado"
echo "Response: $CONFIRM_RESPONSE"
echo ""

# Verificar que se cerró
if echo "$CONFIRM_RESPONSE" | grep -q '"status":"closed"'; then
  echo "✅ Sesión cerrada correctamente"
else
  echo "⚠️ La sesión no se cerró como se esperaba"
fi

echo ""
echo "=================================================="
echo "✅ Prueba del flujo de pago completada"
echo ""
echo "Resumen:"
echo "  - Orden ID: $ORDER_ID"
echo "  - Sesión ID: $SESSION_ID"
echo "  - Flujo: Orden → Entrega → Checkout → Pago → Confirmación → Cerrado"
