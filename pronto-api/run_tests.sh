#!/bin/bash
# Run API Validation Tests for Pronto API Service
# Uso: ./run_tests.sh [OPTIONS]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================="
echo "  Pronto API Test Runner"
echo "========================================="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Determine Python command
PYTHON_CMD="python3"
if command_exists python && ! command_exists python3; then
    PYTHON_CMD="python"
fi

# Activar virtual environment si existe
if [ -d "venv" ]; then
    echo -e "${BLUE}Activando virtual environment local...${NC}"
    source venv/bin/activate
elif [ -d "../../.venv" ]; then
    echo -e "${BLUE}Activando virtual environment del repo...${NC}"
    source ../../.venv/bin/activate
fi

# Instalar dependencias si faltan
echo -e "${BLUE}Verificando dependencias...${NC}"
$PYTHON_CMD -c "import aiohttp" 2>/dev/null || $PYTHON_CMD -m pip install aiohttp python-dotenv --quiet 2>/dev/null || echo -e "${YELLOW}Warning: No se pudieron instalar dependencias${NC}"

# Configurar variables de entorno por defecto
export API_BASE_URL="${API_BASE_URL:-http://localhost:6082}"
export CLIENT_BASE_URL="${CLIENT_BASE_URL:-http://localhost:6080}"
export EMPLOYEES_BASE_URL="${EMPLOYEES_BASE_URL:-http://localhost:6081}"
export ADMIN_EMAIL="${ADMIN_EMAIL:-system@cafeteria.test}"
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-${SEED_EMPLOYEE_PASSWORD:-ChangeMe!123}}"

# Verificar que el script de tests existe
SCRIPT_PATH="scripts/run_api_tests.py"
if [ ! -f "$SCRIPT_PATH" ]; then
    echo -e "${RED}Error: No se encontró $SCRIPT_PATH${NC}"
    exit 1
fi

# Verificar API disponible
echo -e "${BLUE}Verificando API en $API_BASE_URL...${NC}"
if ! $PYTHON_CMD -c "
import urllib.request
req = urllib.request.Request('$API_BASE_URL/health')
with urllib.request.urlopen(req, timeout=5) as r:
    if r.status == 200:
        print('API disponible')
" 2>/dev/null; then
    echo -e "${YELLOW}Warning: API no disponible o sin respuesta${NC}"
fi
echo ""

# Mostrar ayuda si se solicita
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Uso: $0 [OPTIONS]"
    echo ""
    echo "Opciones:"
    echo "  --help, -h              Mostrar esta ayuda"
    echo "  --simple, -s            Modo simple (sin async)"
    echo "  --full, -f              Modo completo (con aiohttp)"
    echo "  --auth-mode             Modo autenticado: login + tests de empleado"
    echo "  --check                 Solo verificar API disponible"
    echo "  --client                Solo APIs de cliente"
    echo "  --employee              Solo APIs de empleado (requiere auth)"
    echo "  --health                Solo health endpoints"
    echo "  --output FILE, -o FILE  Guardar resultados en JSON"
    echo "  --quiet, -q             Modo silencioso"
    echo ""
    echo "Ejemplos:"
    echo "  $0                      # Tests completos"
    echo "  $0 --simple             # Tests simples"
    echo "  $0 --auth-mode          # Login + tests autenticados"
    echo "  $0 -o results.json      # Guardar resultados"
    echo ""
echo "Variables de entorno:"
echo "  API_BASE_URL         URL core API (default: http://localhost:6082)"
echo "  CLIENT_BASE_URL      URL app cliente (default: http://localhost:6080)"
echo "  EMPLOYEES_BASE_URL   URL app empleados (default: http://localhost:6081)"
    echo "  ADMIN_EMAIL      Email para autenticación"
    echo "  ADMIN_PASSWORD   Password para autenticación"
    exit 0
fi

# Ejecutar tests
echo -e "${GREEN}Ejecutando tests...${NC}"
echo "----------------------------------------"
echo ""

$PYTHON_CMD "$SCRIPT_PATH" "$@"

echo ""
echo "========================================="
echo "  Tests Completados"
echo "========================================="
echo ""
echo "Archivos disponibles:"
echo "  - scripts/run_api_tests.py  (script unificado)"
echo "  - API_CHECKLIST.md          (checklist de endpoints)"
