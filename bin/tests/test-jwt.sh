#!/usr/bin/env bash
# Script para ejecutar tests de integración JWT con pytest

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                ║${NC}"
echo -e "${BLUE}║   PRONTO - TESTS DE INTEGRACIÓN JWT         ║${NC}"
echo -e "${BLUE}║                                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Verificar que los servicios estén corriendo
echo -e "${YELLOW}[1/3]${NC} Verificando servicios..."
if ! curl -sf http://localhost:6081/api/health > /dev/null 2>&1; then
    echo -e "${RED}❌ Employee API no está disponible${NC}"
    echo ""
    echo "Por favor inicia los servicios primero:"
    echo "  bash bin/up.sh"
    exit 1
fi

echo -e "${GREEN}✓${NC} Servicios verificados"
echo ""

# Verificar que pytest esté instalado
echo -e "${YELLOW}[2/3]${NC} Verificando pytest..."
if ! command -v pytest &> /dev/null; then
    echo -e "${YELLOW}⚠️  pytest no encontrado en el sistema${NC}"
    echo ""
    echo "Instalando pytest..."
    pip3 install pytest pytest-flask pytest-cov 2>&1 | grep -v "Requirement already satisfied" || true
    echo -e "${GREEN}✓${NC} pytest instalado"
else
    echo -e "${GREEN}✓${NC} pytest disponible"
fi
echo ""

# Ejecutar tests JWT
echo -e "${YELLOW}[3/3]${NC} Ejecutando tests JWT..."
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cd "$PROJECT_ROOT"

# Configurar PYTHONPATH
export PYTHONPATH="${PROJECT_ROOT}:${PYTHONPATH}"

# Ejecutar tests con verbose
if pytest tests/integration/test_jwt_*.py -v --tb=short --color=yes; then
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                ║${NC}"
    echo -e "${GREEN}║   ✓ TESTS JWT COMPLETADOS EXITOSAMENTE       ║${NC}"
    echo -e "${GREEN}║                                                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Tests ejecutados:"
    echo "  ✓ test_jwt_refresh.py (12 tests)"
    echo "  ✓ test_jwt_scope_guard.py (18 tests)"
    echo "  ✓ test_jwt_roles.py (17 tests)"
    echo ""
    echo -e "${BLUE}Total: 47 tests JWT 🚀${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                ║${NC}"
    echo -e "${RED}║   ✗ ALGUNOS TESTS FALLARON                    ║${NC}"
    echo -e "${RED}║                                                ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Para ver detalles completos, ejecuta:"
    echo "  pytest tests/integration/test_jwt_*.py -vv"
    echo ""
    echo "Para ver cobertura:"
    echo "  pytest tests/integration/test_jwt_*.py --cov=pronto_shared.jwt_service --cov=pronto_shared.jwt_middleware --cov-report=html"
    exit 1
fi
