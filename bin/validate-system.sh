#!/usr/bin/env bash
# Script de validación rápido para PRONTO
# Verifica que todos los servicios estén arriba

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         PRONTO - VALIDACIÓN RÁPIDA         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

SERVICES=(
    "API:6082:/health"
    "Employees:6081:/health"
    "Client:6080:/health"
    "Static:9088:"
)

SERVICES_OK=0
SERVICES_FAIL=0

for svc in "${SERVICES[@]}"; do
    IFS=':' read -r name port path <<< "$svc"
    url="http://localhost:$port/$path"

    echo -n "  $name ($port/$path)... "
    if curl -sf -m 3 "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((SERVICES_OK++)) || true
    else
        echo -e "${RED}✗${NC}"
        ((SERVICES_FAIL++)) || true
    fi
done

echo ""

if [ $SERVICES_FAIL -gt 0 ]; then
    echo -e "${RED}❌ $SERVICES_FAIL servicios no disponibles${NC}"
    exit 1
fi

API_BASE="http://localhost:6082/api"

echo -e "${YELLOW}Endpoints principales (pronto-api):${NC}"

ENDPOINTS=(
    "employee-auth/login"
    "employees"
    "areas"
    "menu"
    "orders"
)

ENDPOINTS_OK=0
ENDPOINTS_FAIL=0

for ep in "${ENDPOINTS[@]}"; do
    echo -n "  /api/$ep... "
    response=$(curl -sf -m 10 "$API_BASE/$ep" 2>&1)
    
    if [ $? -eq 0 ]; then
        if echo "$response" | grep -qE "(success|error|\[|\{)"; then
            echo -e "${GREEN}✓${NC}"
            ((ENDPOINTS_OK++)) || true
        else
            echo -e "${YELLOW}?${NC}"
            ((ENDPOINTS_FAIL++)) || true
        fi
    else
        echo -e "${RED}✗${NC}"
        ((ENDPOINTS_FAIL++)) || true
    fi
done

echo ""

echo -e "${YELLOW}Autenticación:${NC}"

echo -n "  Login juan@pronto.com (admin)... "
login_response=$(curl -sf -m 10 -X POST "$API_BASE/employee-auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"juan@pronto.com","password":"ChangeMe!123"}' 2>&1)

if [ $? -eq 0 ]; then
    if echo "$login_response" | grep -q "success"; then
        echo -e "${GREEN}✓ OK${NC}"
        ((AUTH_OK=1)) || true
    else
        echo -e "${YELLOW}⚠ $(echo "$login_response" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)${NC}"
        ((AUTH_OK=0)) || true
    fi
else
    echo -e "${RED}✗${NC}"
    ((AUTH_OK=0)) || true
fi

echo ""

echo -e "${YELLOW}Base de datos:${NC}"

DB_OK=0
DB_FAIL=0

echo -n "  Empleados... "
emp_count=$(docker exec pronto-postgres-1 psql -U pronto -d pronto -t -c "SELECT COUNT(*) FROM pronto_employees;" 2>/dev/null | xargs)
if [ -n "$emp_count" ] && [ "$emp_count" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✓ $emp_count${NC}"
    ((DB_OK++)) || true
else
    echo -e "${RED}✗${NC}"
    ((DB_FAIL++)) || true
fi

echo -n "  Mesas... "
table_count=$(docker exec pronto-postgres-1 psql -U pronto -d pronto -t -c "SELECT COUNT(*) FROM pronto_tables;" 2>/dev/null | xargs)
if [ -n "$table_count" ] && [ "$table_count" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✓ $table_count${NC}"
    ((DB_OK++)) || true
else
    echo -e "${RED}✗${NC}"
    ((DB_FAIL++)) || true
fi

echo ""

echo -e "${YELLOW}Migraciones:${NC}"

echo -n "  Estado migraciones... "
mig_status=$(docker exec -e DATABASE_URL="postgresql://pronto:pronto123@pronto-postgres-1:5432/pronto" \
    -w /opt/pronto/api_app pronto-api-1 /opt/pronto/pronto-scripts/bin/pronto-migrate --check 2>&1)
if echo "$mig_status" | grep -q "pending=0 drift=0"; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${RED}✗${NC}"
fi

echo ""

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              RESUMEN                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo "  ${GREEN}Servicios:${NC} $SERVICES_OK/$(( ${#SERVICES[@]} )) OK"
echo "  ${GREEN}Endpoints:${NC} $ENDPOINTS_OK OK, ${RED}Fail:$ENDPOINTS_FAIL${NC}"
echo "  ${GREEN}Auth:${NC} $([ $AUTH_OK -eq 1 ] && echo "OK" || echo "FAIL")"
echo "  ${GREEN}DB:${NC} $DB_OK OK"
echo ""

if [ $SERVICES_FAIL -eq 0 ]; then
    echo -e "${GREEN}✅ Sistema operativo${NC}"
    echo ""
    echo "Endpoints canonicales:"
    echo "  • API (6082): http://localhost:6082/api/*"
    echo "  • Employees (6081): http://localhost:6081/* (SSR/templates)"
    echo "  • Client (6080): http://localhost:6080/* (SSR/templates)"
    echo "  • Static (9088): http://localhost:9088/assets/*"
    echo ""
    echo "Health endpoints:"
    echo "  • http://localhost:6082/health"
    echo "  • http://localhost:6081/health"
    echo "  • http://localhost:6080/health"
    echo ""
else
    echo -e "${RED}❌ Sistema con problemas${NC}"
    exit 1
fi
