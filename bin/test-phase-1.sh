#!/bin/bash
# FASE 1: Testing Infraestructura y Base de Datos

set -e

echo "========================================"
echo "FASE 1: Infraestructura y Base de Datos"
echo "========================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRONTO_ROOT="$(dirname "$SCRIPT_DIR")"

ERRORS=0
TESTS_PASSED=0
TESTS_FAILED=0

# Función para reportar resultados
report_test() {
    local name="$1"
    local result="$2"
    if [ "$result" -eq 0 ]; then
        echo "✓ $name"
        ((TESTS_PASSED++))
    else
        echo "✗ $name"
        ((TESTS_FAILED++))
        ((ERRORS++))
    fi
}

echo "1. Verificando servicios Docker..."
echo "-----------------------------------"

# Verificar contenedores corriendo
SERVICES_EXPECTED=("pronto-app-postgres" "pronto-app-redis" "pronto-app-api")
for service in "${SERVICES_EXPECTED[@]}"; do
    if docker ps --format "{{.Names}}" | grep -q "$service"; then
        report_test "Servicio $service corriendo" 0
    else
        report_test "Servicio $service corriendo" 1
    fi
done

echo ""
echo "2. Verificando conectividad PostgreSQL..."
echo "------------------------------------------"

# Verificar versión PostgreSQL
if docker exec pronto-app-postgres psql -U pronto -d pronto -c "SELECT version();" > /dev/null 2>&1; then
    report_test "PostgreSQL responde a consultas" 0
else
    report_test "PostgreSQL responde a consultas" 1
fi

# Verificar tablas principales
for table in "pronto_orders" "pronto_dining_sessions" "pronto_menu_items" "pronto_customers" "pronto_employees"; do
    if docker exec pronto-app-postgres psql -U pronto -d pronto -c "SELECT COUNT(*) FROM $table;" > /dev/null 2>&1; then
        report_test "Tabla $table existe" 0
    else
        report_test "Tabla $table existe" 1
    fi
done

echo ""
echo "3. Verificando Redis..."
echo "-----------------------"

if docker exec pronto-app-redis redis-cli ping | grep -q "PONG"; then
    report_test "Redis responde a PING" 0
else
    report_test "Redis responde a PING" 1
fi

echo ""
echo "4. Verificando API Health..."
echo "----------------------------"

if curl -s http://localhost:6082/health > /dev/null 2>&1; then
    report_test "API health endpoint responde" 0
else
    report_test "API health endpoint responde" 1
fi

# Verificar que retorna JSON válido
HEALTH_RESPONSE=$(curl -s http://localhost:6082/health 2>/dev/null)
if echo "$HEALTH_RESPONSE" | grep -q "status"; then
    report_test "API health retorna JSON válido" 0
else
    report_test "API health retorna JSON válido" 1
fi

echo ""
echo "5. Verificando Migraciones..."
echo "-----------------------------"

# Verificar si hay migraciones pendientes (esto es específico del proyecto)
if [ -f "$PRONTO_ROOT/bin/pronto-migrate" ]; then
    if "$PRONTO_ROOT/bin/pronto-migrate" --check > /dev/null 2>&1; then
        report_test "Migraciones aplicadas" 0
    else
        report_test "Migraciones aplicadas" 1
    fi
else
    report_test "Script pronto-migrate existe" 1
fi

echo ""
echo "========================================"
echo "RESUMEN FASE 1"
echo "========================================"
echo "Tests Pasados: $TESTS_PASSED"
echo "Tests Fallidos: $TESTS_FAILED"
echo "Total: $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "✓ FASE 1 COMPLETADA EXITOSAMENTE"
    exit 0
else
    echo "✗ FASE 1 TIENE ERRORES"
    exit 1
fi
