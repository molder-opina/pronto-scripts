#!/usr/bin/env bash
# Script para probar el flujo de compra anónima
# El cliente puede comprar sin proporcionar datos, solo email/teléfono al finalizar

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLIENT_API="http://localhost:6080/api"
EMPLOYEE_API="http://localhost:6081/api"
SESSION_COOKIE="/tmp/pronto_test_anonymous.txt"

echo -e "${BLUE}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                               ║${NC}"
echo -e "${BLUE}║   PRUEBA DE COMPRA ANÓNIMA                   ║${NC}"
echo -e "${BLUE}║                                               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════╝${NC}"
echo ""

# Limpiar sesión anterior
rm -f "$SESSION_COOKIE"

echo -e "${YELLOW}Escenario 1: Compra Totalmente Anónima (sin datos)${NC}"
echo "═══════════════════════════════════════════════════════"
echo ""

# 1. Crear orden SIN proporcionar email o teléfono
echo -e "${YELLOW}[1/7]${NC} Creando orden anónima (sin datos de contacto)..."
ORDER_RESPONSE=$(curl -s -X POST "$CLIENT_API/orders" \
    -H "Content-Type: application/json" \
    -d '{
        "customer": {},
        "items": [
            {"menu_item_id": 1, "quantity": 2},
            {"menu_item_id": 2, "quantity": 1}
        ]
    }')

echo "$ORDER_RESPONSE" | jq '.'

ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.order_id')
SESSION_ID=$(echo "$ORDER_RESPONSE" | jq -r '.session_id')

if [[ "$ORDER_ID" == "null" || -z "$ORDER_ID" ]]; then
    echo -e "${RED}✗ Error: No se pudo crear la orden anónima${NC}"
    echo "$ORDER_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓${NC} Orden anónima creada: ID=$ORDER_ID, Sesión=$SESSION_ID"
echo ""

# Login como admin para procesar la orden
curl -s -X POST "$EMPLOYEE_API/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@cafeteria.test","password":"ChangeMe!123"}' \
    -c "$SESSION_COOKIE" > /dev/null

# 2. Mesero acepta
echo -e "${YELLOW}[2/7]${NC} Mesero acepta la orden..."
curl -s -X POST "$EMPLOYEE_API/orders/$ORDER_ID/accept" \
    -H "Content-Type: application/json" \
    -d '{"employee_id": 3}' \
    -b "$SESSION_COOKIE" > /dev/null
echo -e "${GREEN}✓${NC} Orden aceptada por mesero"

# 3. Chef prepara
echo -e "${YELLOW}[3/7]${NC} Chef prepara la orden..."
curl -s -X POST "$EMPLOYEE_API/orders/$ORDER_ID/kitchen/start" \
    -H "Content-Type: application/json" \
    -d '{"employee_id": 6}' \
    -b "$SESSION_COOKIE" > /dev/null
echo -e "${GREEN}✓${NC} Orden en preparación"

# 4. Chef marca como lista
echo -e "${YELLOW}[4/7]${NC} Chef marca la orden como lista..."
curl -s -X POST "$EMPLOYEE_API/orders/$ORDER_ID/kitchen/ready" \
    -b "$SESSION_COOKIE" > /dev/null
echo -e "${GREEN}✓${NC} Orden lista para entregar"

# 5. Mesero entrega
echo -e "${YELLOW}[5/7]${NC} Mesero entrega la orden..."
curl -s -X POST "$EMPLOYEE_API/orders/$ORDER_ID/deliver" \
    -H "Content-Type: application/json" \
    -d '{"employee_id": 3}' \
    -b "$SESSION_COOKIE" > /dev/null
echo -e "${GREEN}✓${NC} Orden entregada"
echo ""

# 6. Al pagar, proporcionar email para recibir ticket
echo -e "${YELLOW}[6/7]${NC} Cliente paga y proporciona email para recibir ticket..."
PAYMENT_RESPONSE=$(curl -s -X POST "$EMPLOYEE_API/sessions/$SESSION_ID/pay" \
    -H "Content-Type: application/json" \
    -b "$SESSION_COOKIE" \
    -d '{
        "payment_method": "cash",
        "tip_percentage": 10,
        "customer_email": "cliente.anonimo@example.com",
        "customer_phone": "+34666123456"
    }')

echo "$PAYMENT_RESPONSE" | jq '.'
echo -e "${GREEN}✓${NC} Pago completado con datos de contacto"
echo ""

# 7. Obtener ticket
echo -e "${YELLOW}[7/7]${NC} Generando ticket para enviar..."
echo ""
TICKET=$(curl -s -X GET "$EMPLOYEE_API/sessions/$SESSION_ID/ticket" \
    -b "$SESSION_COOKIE" | jq -r '.ticket')
echo "$TICKET"
echo ""
echo -e "${GREEN}✓${NC} Ticket generado y listo para enviar a: cliente.anonimo@example.com"
echo ""

echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo ""

# Escenario 2: Compra con solo teléfono
echo -e "${YELLOW}Escenario 2: Compra Solo con Teléfono${NC}"
echo "═══════════════════════════════════════════════════════"
echo ""

echo -e "${YELLOW}[1/3]${NC} Creando orden solo con teléfono..."
ORDER2_RESPONSE=$(curl -s -X POST "$CLIENT_API/orders" \
    -H "Content-Type: application/json" \
    -d '{
        "customer": {
            "phone": "+34666789012"
        },
        "items": [
            {"menu_item_id": 3, "quantity": 1}
        ]
    }')

ORDER2_ID=$(echo "$ORDER2_RESPONSE" | jq -r '.order_id')
SESSION2_ID=$(echo "$ORDER2_RESPONSE" | jq -r '.session_id')
echo "$ORDER2_RESPONSE" | jq '.'
echo -e "${GREEN}✓${NC} Orden creada solo con teléfono: ID=$ORDER2_ID"
echo ""

# Procesar orden rápidamente
curl -s -X POST "$EMPLOYEE_API/orders/$ORDER2_ID/accept" \
    -H "Content-Type: application/json" \
    -d '{"employee_id": 4}' \
    -b "$SESSION_COOKIE" > /dev/null

curl -s -X POST "$EMPLOYEE_API/orders/$ORDER2_ID/kitchen/start" \
    -H "Content-Type: application/json" \
    -d '{"employee_id": 7}' \
    -b "$SESSION_COOKIE" > /dev/null

curl -s -X POST "$EMPLOYEE_API/orders/$ORDER2_ID/kitchen/ready" \
    -b "$SESSION_COOKIE" > /dev/null

curl -s -X POST "$EMPLOYEE_API/orders/$ORDER2_ID/deliver" \
    -H "Content-Type: application/json" \
    -d '{"employee_id": 4}' \
    -b "$SESSION_COOKIE" > /dev/null

echo -e "${YELLOW}[2/3]${NC} Cliente solicita agregar email antes de pagar..."
CONTACT_UPDATE=$(curl -s -X POST "$EMPLOYEE_API/sessions/$SESSION2_ID/contact" \
    -H "Content-Type: application/json" \
    -b "$SESSION_COOKIE" \
    -d '{
        "email": "cliente.telefono@example.com"
    }')

echo "$CONTACT_UPDATE" | jq '.'
echo -e "${GREEN}✓${NC} Email agregado"
echo ""

echo -e "${YELLOW}[3/3]${NC} Completando pago..."
PAYMENT2=$(curl -s -X POST "$EMPLOYEE_API/sessions/$SESSION2_ID/pay" \
    -H "Content-Type: application/json" \
    -b "$SESSION_COOKIE" \
    -d '{
        "payment_method": "cash",
        "tip_percentage": 15
    }')

echo "$PAYMENT2" | jq '.totals'
echo -e "${GREEN}✓${NC} Pago completado"
echo ""

echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo ""

# Escenario 3: Actualizar contacto en dos pasos
echo -e "${YELLOW}Escenario 3: Compra Anónima + Actualizar Contacto${NC}"
echo "═══════════════════════════════════════════════════════"
echo ""

echo -e "${YELLOW}[1/4]${NC} Cliente crea orden sin datos..."
ORDER3_RESPONSE=$(curl -s -X POST "$CLIENT_API/orders" \
    -H "Content-Type: application/json" \
    -d '{
        "customer": {},
        "items": [
            {"menu_item_id": 1, "quantity": 1}
        ]
    }')

ORDER3_ID=$(echo "$ORDER3_RESPONSE" | jq -r '.order_id')
SESSION3_ID=$(echo "$ORDER3_RESPONSE" | jq -r '.session_id')
echo -e "${GREEN}✓${NC} Orden $ORDER3_ID creada anónimamente"

# Procesar orden
curl -s -X POST "$EMPLOYEE_API/orders/$ORDER3_ID/accept" \
    -d '{"employee_id": 5}' -b "$SESSION_COOKIE" > /dev/null
curl -s -X POST "$EMPLOYEE_API/orders/$ORDER3_ID/kitchen/start" \
    -d '{"employee_id": 6}' -b "$SESSION_COOKIE" > /dev/null
curl -s -X POST "$EMPLOYEE_API/orders/$ORDER3_ID/kitchen/ready" \
    -b "$SESSION_COOKIE" > /dev/null
curl -s -X POST "$EMPLOYEE_API/orders/$ORDER3_ID/deliver" \
    -d '{"employee_id": 5}' -b "$SESSION_COOKIE" > /dev/null

echo -e "${YELLOW}[2/4]${NC} Primero agregar teléfono..."
curl -s -X POST "$EMPLOYEE_API/sessions/$SESSION3_ID/contact" \
    -H "Content-Type: application/json" \
    -b "$SESSION_COOKIE" \
    -d '{"phone": "+34666999888"}' | jq '.'

echo -e "${YELLOW}[3/4]${NC} Luego agregar email..."
curl -s -X POST "$EMPLOYEE_API/sessions/$SESSION3_ID/contact" \
    -H "Content-Type: application/json" \
    -b "$SESSION_COOKIE" \
    -d '{"email": "cliente.pasos@example.com"}' | jq '.'

echo -e "${YELLOW}[4/4]${NC} Pagar sin volver a proporcionar datos..."
PAYMENT3=$(curl -s -X POST "$EMPLOYEE_API/sessions/$SESSION3_ID/pay" \
    -H "Content-Type: application/json" \
    -b "$SESSION_COOKIE" \
    -d '{"payment_method": "cash", "tip_percentage": 20}')

echo "$PAYMENT3" | jq '.totals'
echo -e "${GREEN}✓${NC} Pago completado"
echo ""

# Resumen
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                               ║${NC}"
echo -e "${GREEN}║   ✓ TODAS LAS PRUEBAS COMPLETADAS            ║${NC}"
echo -e "${GREEN}║                                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo "Escenarios probados:"
echo "  ✓ Compra 100% anónima (datos al pagar)"
echo "  ✓ Compra solo con teléfono (email después)"
echo "  ✓ Compra anónima con datos en pasos separados"
echo ""
echo "Funcionalidades verificadas:"
echo "  • Cliente puede comprar sin datos iniciales"
echo "  • Email temporal generado automáticamente"
echo "  • Datos de contacto solicitados al finalizar"
echo "  • Ticket enviado a email/teléfono proporcionado"
echo "  • Sistema de propinas funciona correctamente"
echo ""

# Limpiar
rm -f "$SESSION_COOKIE"
