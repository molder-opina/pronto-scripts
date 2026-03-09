#!/bin/bash
# Script para probar el login desde la línea de comandos

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/lib/docker-runtime.sh
source "${SCRIPT_DIR}/../lib/docker-runtime.sh"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================================"
echo "  PRUEBA DE LOGIN - Sistema de Autenticación"
echo "======================================================"
echo ""

# Configuración
PORT=${EMPLOYEES_PORT:-6081}
HOST="http://localhost:${PORT}"
EMAIL="${1:-admin@cafeteria.test}"
PASSWORD="${2:-ChangeMe!123}"

echo "Host:     ${HOST}"
echo "Email:    ${EMAIL}"
echo "Password: ${PASSWORD}"
echo ""

# Verificar que el servicio esté corriendo
echo "1. Verificando que el servicio esté disponible..."
if ! curl -s -o /dev/null -w "%{http_code}" "${HOST}/" | grep -q "200\|302"; then
    echo -e "${RED}❌ El servicio no está disponible en ${HOST}${NC}"
    echo "   Verifica que los contenedores estén corriendo con: docker-compose ps"
    exit 1
fi
echo -e "${GREEN}✓ Servicio disponible${NC}"
echo ""

# Intentar login
echo "2. Intentando login..."
RESPONSE=$(curl -s -L -c /tmp/cookies.txt -b /tmp/cookies.txt \
    -X POST \
    -d "email=${EMAIL}" \
    -d "password=${PASSWORD}" \
    "${HOST}/login" \
    -w "\nHTTP_CODE:%{http_code}")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)

echo "   HTTP Code: ${HTTP_CODE}"

if echo "$RESPONSE" | grep -q "Bienvenido"; then
    echo -e "${GREEN}✓✓✓ LOGIN EXITOSO ✓✓✓${NC}"
    echo ""
    echo "Respuesta del servidor:"
    echo "$RESPONSE" | head -20
elif echo "$RESPONSE" | grep -q "Credenciales inválidas"; then
    echo -e "${RED}❌ LOGIN FALLIDO: Credenciales inválidas${NC}"
    echo ""
    echo "Posibles causas:"
    echo "  - Email incorrecto"
    echo "  - Password incorrecto"
    echo "  - El empleado no existe en la BD"
    echo ""
    echo "Revisar logs con:"
    echo "  docker-compose logs employees"
elif echo "$RESPONSE" | grep -q "desactivada"; then
    echo -e "${YELLOW}⚠️  CUENTA DESACTIVADA${NC}"
else
    echo -e "${RED}❌ ERROR INESPERADO${NC}"
    echo ""
    echo "Respuesta del servidor:"
    echo "$RESPONSE" | head -30
fi

echo ""
echo "======================================================"
echo "Para ver logs detallados:"
echo "  docker-compose logs -f employees"
echo ""
echo "Para probar con otro usuario:"
echo "  bash bin/tests/test-login.sh juan.mesero@cafeteria.test ChangeMe!123"
echo "======================================================"

# Limpiar
rm -f /tmp/cookies.txt
