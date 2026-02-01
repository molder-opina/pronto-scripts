#!/bin/bash
# =============================================================================
# Script de instalación rápida de herramientas de calidad de código
# =============================================================================

set -e  # Exit on error

echo "=================================================="
echo "🚀 Instalando Herramientas de Calidad de Código"
echo "=================================================="
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Verificar Python
echo -e "${YELLOW}Verificando Python...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 no encontrado. Por favor instálalo primero.${NC}"
    exit 1
fi

PYTHON_VERSION=$(python3 --version)
echo -e "${GREEN}✓ $PYTHON_VERSION encontrado${NC}"
echo ""

# Verificar pip
echo -e "${YELLOW}Verificando pip...${NC}"
if ! command -v pip3 &> /dev/null; then
    echo -e "${RED}❌ pip no encontrado. Instalando...${NC}"
    python3 -m ensurepip --upgrade
fi
echo -e "${GREEN}✓ pip encontrado${NC}"
echo ""

# Actualizar pip
echo -e "${YELLOW}Actualizando pip...${NC}"
python3 -m pip install --upgrade pip
echo ""

# Instalar dependencias de desarrollo
echo -e "${YELLOW}Instalando dependencias de desarrollo...${NC}"
echo "Esto puede tomar algunos minutos..."
python3 -m pip install -r requirements-dev.txt
echo -e "${GREEN}✓ Dependencias instaladas${NC}"
echo ""

# Instalar pre-commit hooks
echo -e "${YELLOW}Instalando pre-commit hooks...${NC}"
pre-commit install
pre-commit install --hook-type commit-msg
echo -e "${GREEN}✓ Pre-commit hooks instalados${NC}"
echo ""

# Limpiar caché
echo -e "${YELLOW}Limpiando caché...${NC}"
make clean 2>/dev/null || true
echo -e "${GREEN}✓ Caché limpiado${NC}"
echo ""

# Verificar instalación
echo -e "${YELLOW}Verificando instalación...${NC}"
echo ""

# Verificar Ruff
if command -v ruff &> /dev/null; then
    RUFF_VERSION=$(ruff --version)
    echo -e "${GREEN}✓ Ruff: $RUFF_VERSION${NC}"
else
    echo -e "${RED}❌ Ruff no instalado correctamente${NC}"
fi

# Verificar Black
if python3 -c "import black" 2>/dev/null; then
    BLACK_VERSION=$(python3 -c "import black; print(f'black {black.__version__}')")
    echo -e "${GREEN}✓ Black: $BLACK_VERSION${NC}"
else
    echo -e "${RED}❌ Black no instalado correctamente${NC}"
fi

# Verificar MyPy
if command -v mypy &> /dev/null; then
    MYPY_VERSION=$(mypy --version)
    echo -e "${GREEN}✓ MyPy: $MYPY_VERSION${NC}"
else
    echo -e "${RED}❌ MyPy no instalado correctamente${NC}"
fi

# Verificar Pytest
if python3 -c "import pytest" 2>/dev/null; then
    PYTEST_VERSION=$(python3 -c "import pytest; print(f'pytest {pytest.__version__}')")
    echo -e "${GREEN}✓ Pytest: $PYTEST_VERSION${NC}"
else
    echo -e "${RED}❌ Pytest no instalado correctamente${NC}"
fi

# Verificar Bandit
if python3 -c "import bandit" 2>/dev/null; then
    echo -e "${GREEN}✓ Bandit instalado${NC}"
else
    echo -e "${RED}❌ Bandit no instalado correctamente${NC}"
fi

# Verificar Pre-commit
if command -v pre-commit &> /dev/null; then
    PRECOMMIT_VERSION=$(pre-commit --version)
    echo -e "${GREEN}✓ Pre-commit: $PRECOMMIT_VERSION${NC}"
else
    echo -e "${RED}❌ Pre-commit no instalado correctamente${NC}"
fi

echo ""
echo "=================================================="
echo -e "${GREEN}✅ Instalación completada!${NC}"
echo "=================================================="
echo ""
echo "📚 Próximos pasos:"
echo ""
echo "1. Lee la documentación:"
echo "   ${YELLOW}cat CODE_QUALITY.md${NC}"
echo ""
echo "2. Ejecuta un quick check:"
echo "   ${YELLOW}make quick-check${NC}"
echo ""
echo "3. Ejecuta todos los tests:"
echo "   ${YELLOW}make test${NC}"
echo ""
echo "4. Ver todos los comandos disponibles:"
echo "   ${YELLOW}make help${NC}"
echo ""
echo "5. Ejecutar pipeline completo de CI:"
echo "   ${YELLOW}make ci${NC}"
echo ""
echo "Los pre-commit hooks se ejecutarán automáticamente en cada commit."
echo "Para ejecutarlos manualmente: ${YELLOW}make pre-commit${NC}"
echo ""
echo -e "${GREEN}¡Happy coding! 🚀${NC}"
