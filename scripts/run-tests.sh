#!/bin/bash
#
# Script de validación completa del proyecto Pronto
# Ejecuta análisis estático, pruebas unitarias, integración y genera reportes
#

set -e  # Exit on error

echo "================================"
echo "Pronto - Test & Validation Suite"
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Activate virtual environment if it exists
if [ -d ".venv" ]; then
    echo "Activating virtual environment..."
    source .venv/bin/activate
else
    echo "${YELLOW}Warning: No virtual environment found${NC}"
fi

# Install development dependencies if needed
if ! command -v pytest &> /dev/null; then
    echo "Installing development dependencies..."
    pip install -r requirements-dev.txt
fi

echo ""
echo "================================"
echo "1. Static Code Analysis"
echo "================================"
echo ""

# Ruff linting
echo "Running Ruff linter..."
if ruff check src/ --output-format=concise 2>&1 | tee ruff-report.txt; then
    echo "${GREEN}✓ Ruff linting passed${NC}"
else
    echo "${YELLOW}⚠ Ruff found some issues (see ruff-report.txt)${NC}"
fi

echo ""

# MyPy type checking (optional, may have many errors initially)
echo "Running MyPy type checker..."
if mypy src/ --ignore-missing-imports 2>&1 | tee mypy-report.txt; then
    echo "${GREEN}✓ MyPy type checking passed${NC}"
else
    echo "${YELLOW}⚠ MyPy found type issues (see mypy-report.txt)${NC}"
fi

echo ""
echo "================================"
echo "2. Security Analysis"
echo "================================"
echo ""

# Bandit security check
echo "Running Bandit security analysis..."
if bandit -r src/ -f txt -o bandit-report.txt 2>&1; then
    echo "${GREEN}✓ Bandit security check passed${NC}"
else
    echo "${YELLOW}⚠ Bandit found security issues (see bandit-report.txt)${NC}"
fi

echo ""
echo "================================"
echo "3. Unit Tests"
echo "================================"
echo ""

# Run unit tests with coverage
echo "Running unit tests..."
if pytest tests/unit/ -v --cov=build --cov-report=html --cov-report=term-missing --cov-report=xml -m "not integration" 2>&1 | tee pytest-unit-report.txt; then
    echo "${GREEN}✓ Unit tests passed${NC}"
else
    echo "${RED}✗ Unit tests failed (see pytest-unit-report.txt)${NC}"
    exit 1
fi

echo ""
echo "================================"
echo "4. Integration Tests"
echo "================================"
echo ""

# Run integration tests
echo "Running integration tests..."
if pytest tests/integration/ -v -m "integration" 2>&1 | tee pytest-integration-report.txt; then
    echo "${GREEN}✓ Integration tests passed${NC}"
else
    echo "${YELLOW}⚠ Integration tests had issues (see pytest-integration-report.txt)${NC}"
fi

echo ""
echo "================================"
echo "5. Test Summary"
echo "================================"
echo ""

# Generate summary
echo "Test Coverage Report:"
if [ -f "htmlcov/index.html" ]; then
    echo "  HTML Coverage Report: htmlcov/index.html"
fi
if [ -f "coverage.xml" ]; then
    echo "  XML Coverage Report: coverage.xml"
fi

echo ""
echo "Static Analysis Reports:"
echo "  Ruff: ruff-report.txt"
echo "  MyPy: mypy-report.txt"
echo "  Bandit: bandit-report.txt"

echo ""
echo "Test Reports:"
echo "  Unit Tests: pytest-unit-report.txt"
echo "  Integration Tests: pytest-integration-report.txt"

echo ""
echo "${GREEN}================================${NC}"
echo "${GREEN}Validation Complete!${NC}"
echo "${GREEN}================================${NC}"
