#!/bin/bash
# ============================================================================
# PRONTO FULL AUDIT CHECKLIST - Auditoría Comprehensiva
# ============================================================================
# Audita los 4 proyectos principales contra las reglas del AGENTS.md
#
# Ejecución: ./pronto-scripts/bin/audit-checklist.sh
# ============================================================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" && pwd)"
cd "$PROJECT_ROOT"

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  PRONTO FULL AUDIT CHECKLIST - $(date +%Y-%m-%d)${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""

PASS=0
WARN=0
FAIL=0

check_pass() { echo -e "  ${GREEN}✓ PASS: $1${NC}"; ((PASS++)); }
check_warn() { echo -e "  ${YELLOW}⚠ WARNING: $1${NC}"; ((WARN++)); }
check_fail() { echo -e "  ${RED}✗ REJECTED: $1${NC}"; ((FAIL++)); }

# ============================================================================
# SECCIÓN 1: PRONTO-API
# ============================================================================
echo -e "${YELLOW}[1/4] AUDITANDO PRONTO-API...${NC}"
echo "---------------------------------------------------------------"
echo "✓ Archivos: $(find pronto-api/src -name "*.py" 2>/dev/null | wc -l) archivos Python"

# [1.2] flask.session PROHIBIDO
echo -e "${BLUE}  [1.2] flask.session (PROHIBIDO)${NC}"
result=$(rg "from flask import session" pronto-api/src -g "*.py" 2>/dev/null | grep -v sqlalchemy | grep -v sessionmaker | wc -l)
if [ "$result" -gt 0 ]; then check_fail "flask.session import found"; else check_pass "No flask.session imports"; fi

# [1.3] JWT obligatorio
echo -e "${BLUE}  [1.3] JWT (OBLIGATORIO)${NC}"
result=$(rg "jwt_required|get_current_user" pronto-api/src -g "*.py" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_pass "JWT middleware used"; else check_fail "JWT no implementado"; fi

# [1.4] Estáticos locales - solo buscar static_folder con valor (no None)
echo -e "${BLUE}  [1.4] Estáticos locales (PROHIBIDO)${NC}"
result=$(rg "static_folder=" pronto-api/src -g "*.py" 2>/dev/null | grep -v "static_folder=None" | grep -v "static_folder='None'" | wc -l)
if [ "$result" -gt 0 ]; then check_fail "Static folder local encontrado"; else check_pass "No static folder local"; fi

# [1.5] Order State Authority - buscar asignaciones directas
echo -e "${BLUE}  [1.5] Order State Authority (P0)${NC}"
result=$(rg "\.workflow_status\s*=" pronto-api/src -g "*.py" 2>/dev/null | grep -v order_state_machine | grep -v constants | wc -l)
if [ "$result" -gt 0 ]; then check_fail "workflow_status = fuera de order_state_machine"; else check_pass "Order state authority OK"; fi

result=$(rg "\.payment_status\s*=" pronto-api/src -g "*.py" 2>/dev/null | grep -v order_state_machine | grep -v constants | wc -l)
if [ "$result" -gt 0 ]; then check_fail "payment_status = fuera de order_state_machine"; else check_pass "Payment state authority OK"; fi

# [1.6] API Parity UUID - algunas entidades pueden usar Integer ID según AGENTS.md
# Excluir debug.py (testing), menu.py y table_assignments.py
echo -e "${BLUE}  [1.6] API Parity UUID${NC}"
result=$(rg "<int:(order_id|session_id|customer_id|employee_id|item_id|table_id|menu_id)" pronto-api/src -g "*.py" 2>/dev/null | grep -v debug.py | grep -v menu.py | grep -v table_assignments.py | wc -l)
if [ "$result" -gt 0 ]; then check_warn "<int:> para entidades UUID"; else check_pass "Tipos de rutas correctos"; fi

# [1.7] CSRF - verificar excepciones válidas
# Excepciones válidas: /health, /sessions/open, client_sessions (table_id)
echo -e "${BLUE}  [1.7] CSRF Protection${NC}"
result=$(rg "@csrf.exempt" pronto-api/src -g "*.py" 2>/dev/null | grep -v health | grep -v sessions/open | grep -v table_id | grep -v client_sessions | wc -l)
if [ "$result" -gt 0 ]; then check_fail "@csrf.exempt prohibited"; else check_pass "CSRF OK (excepciones válidas)"; fi

# [1.8] PII en logs
echo -e "${BLUE}  [1.8] PII en Logs${NC}"
result=$(rg "logger\." pronto-api/src -g "*.py" 2>/dev/null | grep -i "password.*=" | wc -l)
if [ "$result" -gt 0 ]; then check_warn "Posible PII en logs"; else check_pass "No PII en logs"; fi

echo ""

# ============================================================================
# SECCIÓN 2: PRONTO-EMPLOYEES
# ============================================================================
echo -e "${YELLOW}[2/4] AUDITANDO PRONTO-EMPLOYEES...${NC}"
echo "---------------------------------------------------------------"
echo "✓ Archivos: $(find pronto-employees/src -name "*.py" 2>/dev/null | wc -l) archivos Python"

# [2.1] flask.session PROHIBIDO
echo -e "${BLUE}  [2.1] flask.session (PROHIBIDO)${NC}"
result=$(rg "from flask import session" pronto-employees/src -g "*.py" 2>/dev/null | grep -v sqlalchemy | grep -v sessionmaker | wc -l)
if [ "$result" -gt 0 ]; then check_fail "flask.session import found"; else check_pass "No flask.session imports"; fi

# [2.2] JWT obligatorio
echo -e "${BLUE}  [2.2] JWT (OBLIGATORIO)${NC}"
result=$(rg "jwt_required|get_employee_id" pronto-employees/src -g "*.py" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_pass "JWT middleware used"; else check_fail "JWT no implementado"; fi

# [2.3] Estáticos locales
echo -e "${BLUE}  [2.3] Estáticos locales (PROHIBIDO)${NC}"
result=$(rg "static_folder=" pronto-employees/src -g "*.py" 2>/dev/null | grep -v "static_folder=None" | grep -v "static_folder='None'" | wc -l)
if [ "$result" -gt 0 ]; then check_fail "Static folder local encontrado"; else check_pass "No static folder local"; fi

# [2.4] API Parity UUID
echo -e "${BLUE}  [2.4] API Parity UUID${NC}"
result=$(rg "/<int:[a-z_]+_id>" pronto-employees/src -g "*.py" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_warn "<int:> para entidades UUID"; else check_pass "Tipos de rutas correctos"; fi

# [2.5] Roles canónicos
echo -e "${BLUE}  [2.5] Roles Canónicos${NC}"
result=$(rg "Role" pronto-employees/src -g "*.py" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_pass "Roles referenceados"; else check_warn "Verificar roles"; fi

# [2.6] Decoradores web (usa jwt_required, scope_required, admin_required)
echo -e "${BLUE}  [2.6] Decoradores Web${NC}"
result=$(rg "jwt_required|scope_required|admin_required|role_required" pronto-employees/src -g "*.py" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_pass "Auth decorators used"; else check_warn "Verificar decoradores"; fi

echo ""

# ============================================================================
# SECCIÓN 3: PRONTO-CLIENT
# ============================================================================
echo -e "${YELLOW}[3/4] AUDITANDO PRONTO-CLIENT...${NC}"
echo "---------------------------------------------------------------"
echo "✓ Archivos: $(find pronto-client/src -name "*.py" 2>/dev/null | wc -l) archivos Python"

# [3.1] X-PRONTO-CUSTOMER-REF
echo -e "${BLUE}  [3.1] X-PRONTO-CUSTOMER-REF${NC}"
result=$(rg "X-PRONTO-CUSTOMER-REF" pronto-client/src -g "*.py" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_pass "Customer ref header used"; else check_warn "Verificar header de cliente"; fi

# [3.2] Estáticos locales
echo -e "${BLUE}  [3.2] Estáticos locales (PROHIBIDO)${NC}"
result=$(rg "static_folder=" pronto-client/src -g "*.py" 2>/dev/null | grep -v "static_folder=None" | grep -v "static_folder='None'" | wc -l)
if [ "$result" -gt 0 ]; then check_fail "Static folder local encontrado"; else check_pass "No static folder local"; fi

# [3.3] CSRF
echo -e "${BLUE}  [3.3] CSRF Protection${NC}"
result=$(rg "@csrf.exempt" pronto-client/src -g "*.py" 2>/dev/null | grep -v health | wc -l)
if [ "$result" -gt 0 ]; then check_fail "@csrf.exempt prohibited"; else check_pass "CSRF OK"; fi

# [3.4] Templates static
echo -e "${BLUE}  [3.4] Templates static${NC}"
result=$(rg 'href="/static/|src="/static/' pronto-client/src -g "*.html" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_fail "Static local en templates"; else check_pass "No static local en templates"; fi

echo ""

# ============================================================================
# SECCIÓN 4: PRONTO-STATIC (Vue)
# ============================================================================
echo -e "${YELLOW}[4/4] AUDITANDO PRONTO-STATIC...${NC}"
echo "---------------------------------------------------------------"
echo "✓ Archivos Vue: $(find pronto-static/src/vue -name "*.vue" 2>/dev/null | wc -l)"
echo "✓ Archivos TS: $(find pronto-static/src/vue -name "*.ts" 2>/dev/null | wc -l)"

# [4.1] Vue SSR
echo -e "${BLUE}  [4.1] Vue SSR (PROHIBIDO)${NC}"
result=$(rg "createSSRApp|renderToString" pronto-static/src/vue -g "*.ts" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_fail "Vue SSR detectado"; else check_pass "Vue build-only OK"; fi

# [4.2] TypeScript
echo -e "${BLUE}  [4.2] TypeScript (OBLIGATORIO)${NC}"
result=$(rg "<script>" pronto-static/src/vue -g "*.vue" 2>/dev/null | grep -v "lang" | wc -l)
if [ "$result" -gt 0 ]; then check_warn "Verificar JS en componentes"; else check_pass "Solo TypeScript/Vue"; fi

# [4.3] Context variables (buscar en templates Flask, no en archivos Vue)
echo -e "${BLUE}  [4.3] Context Variables${NC}"
result=$(rg "assets_css|assets_js|assets_images" pronto-client/src/pronto_clients/templates -g "*.html" 2>/dev/null | wc -l)
result2=$(rg "assets_css|assets_js|assets_images" pronto-employees/src/pronto_employees/templates -g "*.html" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ] || [ "$result2" -gt 0 ]; then check_pass "Context variables used"; else check_warn "Verificar variables de contexto"; fi

# [4.4] HTTP client
echo -e "${BLUE}  [4.4] HTTP Client${NC}"
result=$(rg "fetch|axios" pronto-static/src/vue -g "*.ts" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_pass "HTTP client used"; fi

# [4.5] Composables
echo -e "${BLUE}  [4.5] Composables${NC}"
result=$(ls pronto-static/src/vue/*/composables/*.ts 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_pass "Composables encontrados"; fi

echo ""

# ============================================================================
# SECCIÓN 5: VERIFICACIONES CRUZADAS
# ============================================================================
echo -e "${YELLOW}[5/4] VERIFICACIONES CRUZADAS...${NC}"
echo "---------------------------------------------------------------"

# [5.1] pronto_shared
echo -e "${BLUE}  [5.1] pronto_shared reuse${NC}"
result=$(rg "from pronto_shared" pronto-api/src -g "*.py" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_pass "Imports de pronto_shared"; else check_warn "Verificar imports"; fi

# [5.2] DDL Runtime
echo -e "${BLUE}  [5.2] DDL Runtime (PROHIBIDO)${NC}"
result=$(rg "^[^#]*CREATE TABLE|^[^#]*ALTER TABLE.*ADD|^[^#]*DROP TABLE" pronto-api/src -g "*.py" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_fail "DDL runtime detectado"; else check_pass "No DDL runtime"; fi

# [5.3] USER_MESSAGES
echo -e "${BLUE}  [5.3] USER_MESSAGES${NC}"
result=$(rg "USER_MESSAGES|error_code|error_message" pronto-api/src -g "*.py" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_pass "User messages used"; else check_warn "Verificar mensajes"; fi

# [5.4] Correlation ID
echo -e "${BLUE}  [5.4] Correlation ID${NC}"
result=$(rg "X-Correlation-ID|correlation_id|request_id" pronto-api/src -g "*.py" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_pass "Correlation ID implemented"; else check_warn "Verificar correlation ID"; fi

# [5.5] Health endpoint
echo -e "${BLUE}  [5.5] Health Endpoint${NC}"
result=$(rg "def.*health|@.*route.*health" pronto-api/src -g "*.py" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_pass "Health endpoint exists"; else check_fail "Falta /health endpoint"; fi

# ============================================================================
# SECCIÓN 6: GATES ADICIONALES
# ============================================================================
echo -e "${YELLOW}[6/4] GATES ADICIONALES...${NC}"
echo "---------------------------------------------------------------"

# [6.1] Gate G: API Parity
echo -e "${BLUE}  [6.1] Gate G: API Parity (P1)${NC}"
result=$(rg "/<int:[a-z_]+_id>" pronto-employees/src -g "*.py" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_warn "<int:> para entidades UUID"; else check_pass "API Parity OK"; fi

# [6.2] PostgreSQL
echo -e "${BLUE}  [6.2] PostgreSQL 16-alpine${NC}"
result=$(rg "postgres:16-alpine" docker-compose*.yml 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_pass "PostgreSQL 16-alpine"; else check_warn "Verificar versión PostgreSQL"; fi

# [6.3] legacy_mysql
echo -e "${BLUE}  [6.3] legacy_mysql PROHIBIDO${NC}"
if [ -d "pronto-scripts/init/legacy_mysql" ]; then check_fail "legacy_mysql existe"; else check_pass "No legacy_mysql"; fi

# [6.4] PRONTO_ROUTES_ONLY
echo -e "${BLUE}  [6.4] PRONTO_ROUTES_ONLY${NC}"
result=$(rg "PRONTO_ROUTES_ONLY" pronto-employees/src -g "*.py" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_pass "PRONTO_ROUTES_ONLY soportado"; else check_warn "Verificar PRONTO_ROUTES_ONLY"; fi

# [6.5] ScopeGuard
echo -e "${BLUE}  [6.5] ScopeGuard (aislamiento)${NC}"
result=$(rg "ScopeGuard" pronto-employees/src -g "*.py" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_pass "ScopeGuard implementado"; else check_warn "Verificar ScopeGuard"; fi

# [6.6] Router semántico
echo -e "${BLUE}  [6.6] Router semántico${NC}"
if [ -f "pronto-ai/router.yml" ]; then check_pass "router.yml existe"; else check_warn "Verificar router.yml"; fi

# [6.7] PRONTO_SYSTEM_VERSION
echo -e "${BLUE}  [6.7] PRONTO_SYSTEM_VERSION${NC}"
result=$(rg "PRONTO_SYSTEM_VERSION" .env 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_pass "VERSION presente"; else check_warn "Verificar VERSION"; fi

# [6.8] Error tracking
echo -e "${BLUE}  [6.8] Error Tracking${NC}"
if [ -d "pronto-docs/errors" ]; then check_pass "pronto-docs/errors existe"; else check_warn "Verificar error tracking"; fi

# [6.9] RBAC Service
echo -e "${BLUE}  [6.9] RBAC Service (P0)${NC}"
result=$(rg "RBACService" pronto-libs/src -g "*.py" 2>/dev/null | wc -l)
if [ "$result" -gt 0 ]; then check_pass "RBACService implementado"; else check_warn "Verificar RBACService"; fi

# ============================================================================
# RESUMEN
# ============================================================================
echo ""
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}  RESUMEN DE AUDITORÍA${NC}"
echo -e "${BLUE}============================================================${NC}"
echo -e "${GREEN}  ✓ PASS:   $PASS${NC}"
echo -e "${YELLOW}  ⚠ WARN:   $WARN${NC}"
echo -e "${RED}  ✗ FAIL:   $FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}  🎉 AUDITORÍA PASSED - Sin bloqueantes${NC}"
else
    echo -e "${RED}  ⚠️  AUDITORÍA CON FALLOS - Corregir antes de deploy${NC}"
fi

echo -e "${BLUE}============================================================${NC}"
