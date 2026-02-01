#!/bin/bash

# Script para ejecutar todos los tests de Pronto App
# Uso: ./run-all-tests.sh [options]
# Options:
#   -b, --backend     Solo ejecutar tests del backend
#   -f, --frontend    Solo ejecutar tests del frontend
#   -e, --e2e         Solo ejecutar tests E2E
#   -u, --unit        Solo ejecutar tests unitarios
#   -i, --integration Solo ejecutar tests de integración
#   -c, --coverage    Ejecutar con reporte de cobertura
#   -v, --verbose     Modo verbose
#   -h, --help        Mostrar ayuda

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Flags
RUN_BACKEND=true
RUN_FRONTEND=true
RUN_E2E=false
RUN_UNIT=false
RUN_INTEGRATION=false
COVERAGE=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--backend)
      RUN_BACKEND=true
      RUN_FRONTEND=false
      RUN_E2E=false
      shift
      ;;
    -f|--frontend)
      RUN_BACKEND=false
      RUN_FRONTEND=true
      RUN_E2E=false
      shift
      ;;
    -e|--e2e)
      RUN_BACKEND=false
      RUN_FRONTEND=false
      RUN_E2E=true
      shift
      ;;
    -u|--unit)
      RUN_UNIT=true
      RUN_INTEGRATION=false
      shift
      ;;
    -i|--integration)
      RUN_UNIT=false
      RUN_INTEGRATION=true
      shift
      ;;
    -c|--coverage)
      COVERAGE=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      echo "Uso: ./run-all-tests.sh [options]"
      echo ""
      echo "Options:"
      echo "  -b, --backend         Solo ejecutar tests del backend"
      echo "  -f, --frontend        Solo ejecutar tests del frontend"
      echo "  -e, --e2e             Solo ejecutar tests E2E"
      echo "  -u, --unit            Solo ejecutar tests unitarios"
      echo "  -i, --integration    Solo ejecutar tests de integración"
      echo "  -c, --coverage        Ejecutar con reporte de cobertura"
      echo "  -v, --verbose         Modo verbose"
      echo "  -h, --help            Mostrar ayuda"
      echo ""
      echo "Ejemplos:"
      echo "  ./run-all-tests.sh                # Ejecutar todos los tests"
      echo "  ./run-all-tests.sh -b             # Solo backend"
      echo "  ./run-all-tests.sh -f -c          # Frontend con cobertura"
      echo "  ./run-all-tests.sh -e             # Solo E2E"
      echo "  ./run-all-tests.sh -u             # Solo tests unitarios"
      exit 0
      ;;
    *)
      echo "Opción desconocida: $1"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Pronto App - Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

FAILED=false
TOTAL_TESTS=0
PASSED_TESTS=0

# Backend tests (pytest)
if [ "$RUN_BACKEND" = true ]; then
  echo -e "${YELLOW}Ejecutando tests del Backend...${NC}"

  if [ ! -d ".venv" ]; then
    echo -e "${RED}Error: No se encontró el entorno virtual${NC}"
    echo "Ejecuta: python -m venv .venv && source .venv/bin/activate && pip install -r requirements-dev.txt"
    exit 1
  fi

  test_cmd="source .venv/bin/activate && pytest"

  if [ "$COVERAGE" = true ]; then
    test_cmd="$test_cmd --cov=build --cov-report=html --cov-report=term"
  fi

  if [ "$VERBOSE" = true ]; then
    test_cmd="$test_cmd -v"
  fi

  if [ "$RUN_UNIT" = true ]; then
    test_cmd="$test_cmd -m unit"
  fi

  if [ "$RUN_INTEGRATION" = true ]; then
    test_cmd="$test_cmd -m integration"
  fi

  eval $test_cmd

  if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Backend tests failed${NC}"
    FAILED=true
  else
    echo -e "${GREEN}✅ Backend tests passed${NC}"
  fi
  echo ""
fi

# Frontend tests (Vitest)
if [ "$RUN_FRONTEND" = true ]; then
  echo -e "${YELLOW}Ejecutando tests del Frontend...${NC}"

  if [ ! -d "node_modules" ]; then
    echo -e "${RED}Error: No se encontraron las dependencias del frontend${NC}"
    echo "Ejecuta: npm install"
    exit 1
  fi

  test_cmd="npm run test -- --run"

  if [ "$COVERAGE" = true ]; then
    test_cmd="npm run test:coverage"
  fi

  eval $test_cmd

  if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Frontend tests failed${NC}"
    FAILED=true
  else
    echo -e "${GREEN}✅ Frontend tests passed${NC}"
  fi
  echo ""
fi

# E2E tests (Playwright)
if [ "$RUN_E2E" = true ]; then
  echo -e "${YELLOW}Ejecutando tests E2E...${NC}"

  if [ ! -d "e2e-tests/node_modules" ]; then
    echo -e "${RED}Error: No se encontraron las dependencias E2E${NC}"
    echo "Ejecuta: cd e2e-tests && npm install && npx playwright install"
    exit 1
  fi

  cd e2e-tests

  if [ "$VERBOSE" = true ]; then
    npm run test
  else
    npm run test -- --reporter=line
  fi

  if [ $? -ne 0 ]; then
    echo -e "${RED}❌ E2E tests failed${NC}"
    FAILED=true
  else
    echo -e "${GREEN}✅ E2E tests passed${NC}"
  fi
  cd ..
  echo ""
fi

echo -e "${BLUE}========================================${NC}"
if [ "$FAILED" = true ]; then
  echo -e "${RED}  ❌ Tests FAILED${NC}"
  echo -e "${BLUE}========================================${NC}"
  exit 1
else
  echo -e "${GREEN}  ✅ All tests PASSED${NC}"
  echo -e "${BLUE}========================================${NC}"
  exit 0
fi
