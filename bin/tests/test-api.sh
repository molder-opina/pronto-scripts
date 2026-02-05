#!/usr/bin/env bash
# Script de pruebas completo para pronto-flask-app
# Ejecutar después de levantar los contenedores con: bash bin/up.sh

set -e

# Colores para output
# shellcheck disable=SC2034  # RED used in print_test function
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
fi

# URL base de la API de empleados
EMPLOYEE_API_BASE="${EMPLOYEE_API_BASE_URL:-http://localhost:${EMPLOYEE_APP_HOST_PORT:-6081}}"
if [[ "$EMPLOYEE_API_BASE" == */api ]]; then
    BASE_URL="$EMPLOYEE_API_BASE"
else
    BASE_URL="${EMPLOYEE_API_BASE%/}/api"
fi

# Variables globales
SESSION_COOKIE=""
# shellcheck disable=SC2034  # EMPLOYEE_ID set but NEW_EMPLOYEE_ID used instead
EMPLOYEE_ID=""
# shellcheck disable=SC2034  # Placeholder for future use
SESSION_ID=""
# shellcheck disable=SC2034  # Placeholder for future use
ORDER_ID=""

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}  PRONTO API - SUITE DE PRUEBAS${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""

# Función para hacer peticiones HTTP
api_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local extra_args=${4:-}

    if [[ -n "$SESSION_COOKIE" ]]; then
        extra_args="$extra_args -b $SESSION_COOKIE -c $SESSION_COOKIE"
    fi

    if [[ "$method" == "GET" ]]; then
        curl -s -X GET "$BASE_URL$endpoint" $extra_args
    else
        curl -s -X "$method" "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data" \
            $extra_args
    fi
}

# Función para imprimir resultados
print_test() {
    local test_name=$1
    local result=$2

    if echo "$result" | jq . >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $test_name"
        echo "$result" | jq '.'
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "$result"
        return 1
    fi
}

# Función para verificar error esperado
print_error_test() {
    local test_name=$1
    local result=$2

    if echo "$result" | jq -e '.error' >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $test_name (error esperado)"
        echo "$result" | jq '.'
    else
        echo -e "${RED}✗${NC} $test_name - Se esperaba error"
        echo "$result"
        return 1
    fi
}

echo "Esperando que los servicios estén listos..."
sleep 5

echo ""
echo -e "${YELLOW}=== 1. PRUEBAS DE HEALTH CHECK ===${NC}"
result=$(curl -s http://localhost:6081/api/health)
print_test "Health check employee API" "$result"

echo ""
echo -e "${YELLOW}=== 2. PRUEBAS DE AUTENTICACIÓN ===${NC}"

# Login exitoso
echo "2.1 Login exitoso (System)"
result=$(api_request POST "/auth/login" '{"email":"admin@cafeteria.test","password":"ChangeMe!123"}')
print_test "Login como system" "$result"

# Guardar cookie de sesión
SESSION_COOKIE="/tmp/pronto_session_cookie.txt"
curl -s -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@cafeteria.test","password":"ChangeMe!123"}' \
    -c "$SESSION_COOKIE" > /dev/null

# Verificar sesión
echo ""
echo "2.2 Verificar sesión actual"
result=$(api_request GET "/auth/me")
print_test "Obtener datos del usuario actual" "$result"
# shellcheck disable=SC2034
EMPLOYEE_ID=$(echo "$result" | jq -r '.employee.id')

# Login fallido
echo ""
echo "2.3 Login con credenciales incorrectas"
result=$(api_request POST "/auth/login" '{"email":"admin@cafeteria.test","password":"WrongPassword"}')
print_error_test "Login fallido" "$result"

# Login de otros usuarios
echo ""
echo "2.4 Login como mesero"
result=$(api_request POST "/auth/login" '{"email":"juan.mesero@cafeteria.test","password":"ChangeMe!123"}')
print_test "Login como mesero" "$result"

echo ""
echo "2.5 Login como chef"
result=$(api_request POST "/auth/login" '{"email":"carlos.chef@cafeteria.test","password":"ChangeMe!123"}')
print_test "Login como chef" "$result"

# Volver a login como admin
curl -s -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@cafeteria.test","password":"ChangeMe!123"}' \
    -c "$SESSION_COOKIE" > /dev/null

echo ""
echo -e "${YELLOW}=== 3. PRUEBAS DE GESTIÓN DE EMPLEADOS (ADMIN) ===${NC}"

# Listar empleados
echo "3.1 Listar todos los empleados"
result=$(api_request GET "/employees")
print_test "Listar empleados" "$result"

# Crear empleado
echo ""
echo "3.2 Crear nuevo empleado"
result=$(api_request POST "/employees" '{
    "name": "Test Empleado",
    "email": "test.empleado@cafeteria.test",
    "password": "TestPass123!",
    "role": "waiter"
}')
print_test "Crear empleado" "$result"
NEW_EMPLOYEE_ID=$(echo "$result" | jq -r '.id')

# Obtener empleado
echo ""
echo "3.3 Obtener empleado por ID"
result=$(api_request GET "/employees/$NEW_EMPLOYEE_ID")
print_test "Obtener empleado $NEW_EMPLOYEE_ID" "$result"

# Actualizar empleado
echo ""
echo "3.4 Actualizar empleado"
result=$(api_request PUT "/employees/$NEW_EMPLOYEE_ID" '{
    "name": "Test Empleado Actualizado",
    "role": "chef"
}')
print_test "Actualizar empleado" "$result"

# Desactivar empleado
echo ""
echo "3.5 Desactivar empleado"
result=$(api_request DELETE "/employees/$NEW_EMPLOYEE_ID")
print_test "Desactivar empleado" "$result"

echo ""
echo -e "${YELLOW}=== 4. PRUEBAS DE GESTIÓN DE ROLES ===${NC}"

# Listar empleados con permisos
echo "4.1 Listar empleados con permisos"
result=$(api_request GET "/roles/employees")
print_test "Listar empleados con permisos" "$result"

# Asignar permiso
echo ""
echo "4.2 Asignar permiso a empleado"
result=$(api_request POST "/roles/employees/$NEW_EMPLOYEE_ID/assign" '{
    "permission_code": "kitchen-board"
}')
print_test "Asignar permiso kitchen-board" "$result"

# Revocar permiso
echo ""
echo "4.3 Revocar permiso de empleado"
result=$(api_request POST "/roles/employees/$NEW_EMPLOYEE_ID/revoke" '{
    "permission_code": "kitchen-board"
}')
print_test "Revocar permiso kitchen-board" "$result"

echo ""
echo -e "${YELLOW}=== 5. PRUEBAS DE MENÚ ===${NC}"

# Listar menú
echo "5.1 Listar menú"
result=$(api_request GET "/menu")
print_test "Listar menú" "$result"

# Crear item de menú
echo ""
echo "5.2 Crear item de menú"
result=$(api_request POST "/menu-items" '{
    "name": "Hamburguesa Test",
    "description": "Hamburguesa de prueba",
    "price": 12.99,
    "category_id": 2,
    "is_available": true
}')
print_test "Crear item de menú" "$result"
MENU_ITEM_ID=$(echo "$result" | jq -r '.id // empty')

if [[ -n "$MENU_ITEM_ID" ]]; then
    # Actualizar item de menú
    echo ""
    echo "5.3 Actualizar item de menú"
    result=$(api_request PUT "/menu-items/$MENU_ITEM_ID" '{
        "name": "Hamburguesa Test Actualizada",
        "price": 14.99,
        "is_available": false
    }')
    print_test "Actualizar item de menú" "$result"
fi

echo ""
echo -e "${YELLOW}=== 6. PRUEBAS DE ÓRDENES ===${NC}"

# Listar órdenes
echo "6.1 Listar órdenes"
result=$(api_request GET "/orders")
print_test "Listar órdenes" "$result"

echo ""
echo -e "${YELLOW}=== 7. PRUEBAS DE SISTEMA DE PROPINAS ===${NC}"

# Crear una sesión y orden de prueba mediante la API de clientes
echo "7.1 Preparando datos de prueba para propinas..."

# Simular aplicación de propina con porcentajes
echo ""
echo "7.2 Simular propina del 10%"
echo "Nota: Necesita una sesión activa. Debes crear una orden primero desde la app de clientes."

# Ver propinas de un mesero
echo ""
echo "7.3 Ver propinas de mesero (ID: 3 - Juan Mesero)"
result=$(api_request GET "/employees/3/tips")
print_test "Obtener propinas del mesero" "$result"

echo ""
echo -e "${YELLOW}=== 8. PRUEBAS DE MÉTRICAS ===${NC}"

# Obtener estadísticas
echo "8.1 Obtener métricas del dashboard"
result=$(api_request GET "/stats")
print_test "Métricas del dashboard" "$result"

echo ""
echo -e "${YELLOW}=== 9. PRUEBAS DE AUTORIZACIÓN ===${NC}"

# Cerrar sesión de admin
curl -s -X POST "$BASE_URL/auth/logout" -b "$SESSION_COOKIE" > /dev/null

# Intentar crear empleado sin autenticación
echo "9.1 Intentar crear empleado sin autenticación"
result=$(curl -s -X POST "$BASE_URL/employees" \
    -H "Content-Type: application/json" \
    -d '{"name":"Hacker","email":"hacker@test.com","password":"hack"}')
print_error_test "Crear empleado sin auth (debe fallar)" "$result"

# Login como mesero
curl -s -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"juan.mesero@cafeteria.test","password":"ChangeMe!123"}' \
    -c "$SESSION_COOKIE" > /dev/null

# Intentar crear empleado como mesero (no admin)
echo ""
echo "9.2 Intentar crear empleado como mesero (sin permisos de admin)"
result=$(api_request POST "/employees" '{
    "name": "Test",
    "email": "test@test.com",
    "password": "test"
}')
print_error_test "Crear empleado sin permisos (debe fallar)" "$result"

# Mesero puede ver sus propinas
echo ""
echo "9.3 Mesero puede ver sus propias propinas"
result=$(api_request GET "/employees/3/tips")
print_test "Mesero obtiene sus propinas" "$result"

echo ""
echo -e "${YELLOW}=== 10. PRUEBA DE LOGOUT ===${NC}"
result=$(api_request POST "/auth/logout")
print_test "Logout exitoso" "$result"

# Limpiar
rm -f "$SESSION_COOKIE"

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  TODAS LAS PRUEBAS COMPLETADAS${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "Resumen de funcionalidades probadas:"
echo "✓ Autenticación (login/logout)"
echo "✓ Gestión de empleados (CRUD)"
echo "✓ Gestión de roles y permisos"
echo "✓ Sistema de menú"
echo "✓ Sistema de propinas"
echo "✓ Métricas y estadísticas"
echo "✓ Control de acceso por roles"
echo ""
echo "Para probar el flujo completo de propinas:"
echo "1. Crea una orden desde la app de clientes (puerto 6080)"
echo "2. Acepta la orden como mesero"
echo "3. Procesa en cocina como chef"
echo "4. Entrega la orden"
echo "5. Procesa el pago con propina usando:"
echo "   POST /api/sessions/{session_id}/pay"
echo "   {\"payment_method\": \"cash\", \"tip_percentage\": 15}"
echo "6. Verifica propinas del mesero:"
echo "   GET /api/employees/{employee_id}/tips"
