#!/usr/bin/env bash
# Script principal para ejecutar todas las pruebas de pronto-flask-app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                ║${NC}"
echo -e "${BLUE}║   PRONTO - SUITE COMPLETA DE PRUEBAS        ║${NC}"
echo -e "${BLUE}║                                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Verificar que los servicios estén corriendo
echo -e "${YELLOW}[1/4]${NC} Verificando servicios..."
if ! curl -sf http://localhost:6081/health > /dev/null 2>&1; then
    echo -e "${RED}❌ Employee API no está disponible${NC}"
    echo ""
    echo "Por favor inicia los servicios primero:"
    echo "  bash bin/up.sh"
    exit 1
fi

if ! curl -sf http://localhost:6080/health > /dev/null 2>&1; then
    echo -e "${RED}❌ Client API no está disponible${NC}"
    echo ""
    echo "Por favor inicia los servicios primero:"
    echo "  bash bin/up.sh"
    exit 1
fi

echo -e "${GREEN}✓${NC} Servicios verificados"
echo ""

# Ejecutar pruebas básicas
echo -e "${YELLOW}[2/4]${NC} Ejecutando pruebas de API..."
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if bash "${SCRIPT_DIR}/tests/test-api.sh"; then
    echo -e "${GREEN}✓ Pruebas de API completadas exitosamente${NC}"
else
    echo -e "${RED}✗ Algunas pruebas de API fallaron${NC}"
    exit 1
fi
echo ""

# Ejecutar pruebas de flujo de propinas
echo -e "${YELLOW}[3/4]${NC} Ejecutando pruebas de flujo de propinas..."
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if bash "${SCRIPT_DIR}/tests/test-tips-flow.sh"; then
    echo -e "${GREEN}✓ Pruebas de propinas completadas exitosamente${NC}"
else
    echo -e "${RED}✗ Algunas pruebas de propinas fallaron${NC}"
    exit 1
fi
echo ""

# Ejecutar pruebas de compra anónima
echo -e "${YELLOW}[4/4]${NC} Ejecutando pruebas de compra anónima..."
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if bash "${SCRIPT_DIR}/tests/test-anonymous.sh"; then
    echo -e "${GREEN}✓ Pruebas de compra anónima completadas${NC}"
else
    echo -e "${RED}✗ Algunas pruebas de compra anónima fallaron${NC}"
    exit 1
fi
echo ""

# Resumen final
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                ║${NC}"
echo -e "${GREEN}║   ✓ TODAS LAS PRUEBAS COMPLETADAS             ║${NC}"
echo -e "${GREEN}║                                                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo "Pruebas ejecutadas:"
echo "  ✓ Pruebas de API (autenticación, empleados, roles)"
echo "  ✓ Pruebas de flujo de propinas"
echo "  ✓ Pruebas de compra anónima"
echo ""
echo -e "${BLUE}Todos los sistemas funcionando correctamente 🚀${NC}"
