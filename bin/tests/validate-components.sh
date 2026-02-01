#!/bin/bash
# =============================================================================
# COMPONENT VALIDATOR SCRIPT
# Validates that all required system components are working correctly
# =============================================================================
#
# Usage:
#   ./bin/validate-components.sh [--quick] [--verbose] [--fix]
#
# Options:
#   --quick      Quick validation (only essential checks)
#   --verbose    Show detailed output
#   --fix        Attempt to fix common issues automatically
#
# Exit codes:
#   0 - All components validated successfully
#   1 - Some components failed validation
#   2 - Invalid options or missing dependencies
#
# =============================================================================

set -e

# Colors for output
RED='\033[91m'
GREEN='\033[92m'
YELLOW='\033[93m'
BLUE='\033[94m'
BOLD='\033[1m'
RESET='\033[0m'

# Default values
VERBOSE=false
QUICK=false
FIX=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --fix)
            FIX=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--quick] [--verbose] [--fix]"
            exit 2
            ;;
    esac
done

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${RESET} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${RESET} $1"
}

log_section() {
    echo ""
    echo -e "${BOLD}${BLUE}=== $1 ===${RESET}"
}

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNED_CHECKS=0

# =============================================================================
# CHECK 1: DOCKER SERVICES
# =============================================================================
check_docker_services() {
    log_section "Docker Services"

    # Check if Docker is running
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if docker info >/dev/null 2>&1; then
        log_pass "Docker is running"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_fail "Docker is not running or not accessible"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi

    # Check required containers
    local required_containers=("pronto-client" "pronto-employee" "pronto-postgres" "pronto-redis")
    local running_containers=$(docker ps --format '{{.Names}}' 2>/dev/null || echo "")

    for container in "${required_containers[@]}"; do
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        if echo "$running_containers" | grep -q "$container"; then
            log_pass "$container is running"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            log_fail "$container is NOT running"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))

            if [ "$FIX" = true ]; then
                log_info "Attempting to start $container..."
                docker compose start "$container" 2>/dev/null || true
            fi
        fi
    done
}

# =============================================================================
# CHECK 2: PORT ACCESSIBILITY
# =============================================================================
check_ports() {
    log_section "Port Accessibility"

    local ports=(
        "6080:Client App"
        "6081:Employee App"
        "6082:API Service"
        "5432:PostgreSQL"
        "6379:Redis"
        "9088:Static Assets"
    )

    for port_info in "${ports[@]}"; do
        local port=$(echo "$port_info" | cut -d':' -f1)
        local name=$(echo "$port_info" | cut -d':' -f2)

        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port" 2>/dev/null | grep -qE "200|302|404"; then
            log_pass "Port $port ($name) - accessible"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            log_fail "Port $port ($name) - NOT accessible"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    done
}

# =============================================================================
# CHECK 3: API HEALTH ENDPOINTS
# =============================================================================
check_api_health() {
    log_section "API Health Endpoints"

    local endpoints=(
        "http://localhost:6080/api/health:Client API"
        "http://localhost:6081/api/health:Employee API"
        "http://localhost:6081/api/stats/public:Public Stats"
    )

    for endpoint_info in "${endpoints[@]}"; do
        local url=$(echo "$endpoint_info" | cut -d':' -f1,2,3)
        local name=$(echo "$endpoint_info" | cut -d':' -f4-)

        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        local status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

        if [ "$status" = "200" ]; then
            log_pass "$name - Healthy (HTTP $status)"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        elif [ "$status" = "000" ]; then
            log_fail "$name - Connection failed"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            log_warn "$name - Status: HTTP $status"
            WARNED_CHECKS=$((WARNED_CHECKS + 1))
        fi
    done
}

# =============================================================================
# CHECK 4: DATABASE CONNECTIVITY
# =============================================================================
check_database() {
    log_section "Database Connectivity"

    # Use configured credentials
    local PG_HOST="${POSTGRES_HOST:-localhost}"
    local PG_PORT="${POSTGRES_PORT:-5432}"
    local PG_USER="${POSTGRES_USER:-pronto}"
    local PG_DB="${POSTGRES_DB:-pronto}"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if PGPASSWORD="${POSTGRES_PASSWORD:-pronto123}" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT 1;" >/dev/null 2>&1; then
        log_pass "PostgreSQL connection successful"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_fail "PostgreSQL connection failed"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi

    # Check critical tables
    local tables=("pronto_orders" "pronto_menu_items" "pronto_employees" "pronto_sessions")

    for table in "${tables[@]}"; do
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        local count=$(PGPASSWORD="${POSTGRES_PASSWORD:-pronto123}" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -t -c "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "0")

        if [ "$count" -gt 0 ] 2>/dev/null; then
            log_pass "Table $table - $count rows"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            log_warn "Table $table - empty or not found"
            WARNED_CHECKS=$((WARNED_CHECKS + 1))
        fi
    done
}

# =============================================================================
# CHECK 5: REDIS CONNECTIVITY
# =============================================================================
check_redis() {
    log_section "Redis Connectivity"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    # Verificar si redis-cli está disponible
    if ! command -v redis-cli &> /dev/null; then
        log_warn "Redis CLI no está instalado (skipped)"
        WARNED_CHECKS=$((WARNED_CHECKS + 1))
        return 0
    fi

    # Verificar conectividad
    if redis-cli -p 6379 ping >/dev/null 2>&1; then
        log_pass "Redis connection successful"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))

        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        local key_count=$(redis-cli -p 6379 dbsize 2>/dev/null || echo "0")
        log_pass "Redis keys in database: $key_count"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_fail "Redis connection failed"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# =============================================================================
# CHECK 6: JWT CONFIGURATION
# =============================================================================
check_jwt_config() {
    log_section "JWT Configuration"

    local secret_file="config/secrets.env"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ -f "$secret_file" ]; then
        log_pass "JWT secrets file exists"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_fail "JWT secrets file not found"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if grep -q "SECRET_KEY\|JWT" "$secret_file" 2>/dev/null; then
        log_pass "JWT configuration present"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_warn "JWT configuration may be missing"
        WARNED_CHECKS=$((WARNED_CHECKS + 1))
    fi
}

# =============================================================================
# CHECK 7: STATIC ASSETS
# =============================================================================
check_static_assets() {
    log_section "Static Assets"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:9088/" 2>/dev/null | grep -qE "200|404"; then
        log_pass "Static server accessible"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_warn "Static server may not be accessible from host"
        WARNED_CHECKS=$((WARNED_CHECKS + 1))
    fi

    # Check if built assets exist
    local assets_dir="src/shared/static/js/dist/clients"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ -d "$assets_dir" ]; then
        local file_count=$(find "$assets_dir" -name "*.js" 2>/dev/null | wc -l)
        log_pass "Client assets directory - $file_count JS files"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_fail "Client assets directory not found"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# =============================================================================
# CHECK 8: ENVIRONMENT CONFIGURATION
# =============================================================================
check_env_config() {
    log_section "Environment Configuration"

    local config_files=("config/general.env" "config/secrets.env")

    for config_file in "${config_files[@]}"; do
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        if [ -f "$config_file" ]; then
            log_pass "$config_file exists"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            log_fail "$config_file not found"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    done

    # Check required environment variables
    local required_vars=("POSTGRES_HOST" "POSTGRES_DB" "SECRET_KEY")

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    local all_present=true
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" config/general.env 2>/dev/null && ! grep -q "^$var=" config/secrets.env 2>/dev/null; then
            all_present=false
            break
        fi
    done

    if $all_present; then
        log_pass "All required environment variables present"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_warn "Some environment variables may be missing"
        WARNED_CHECKS=$((WARNED_CHECKS + 1))
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
main() {
    echo ""
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${BLUE}║           COMPONENT VALIDATION SCRIPT                      ║${RESET}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Mode: $([ "$QUICK" = true ] && echo "Quick" || echo "Full")"
    echo ""

    # Load environment variables
    if [ -f "config/general.env" ]; then
        set -a
        source config/general.env 2>/dev/null || true
        set +a
    fi

    # Run checks
    check_docker_services

    if [ "$QUICK" = false ]; then
        check_ports
        check_api_health
        check_database
        check_redis
        check_jwt_config
        check_static_assets
        check_env_config
    fi

    # Summary
    echo ""
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${BLUE}                    VALIDATION SUMMARY                        ${RESET}"
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════${RESET}"
    echo ""
    echo -e "  ${GREEN}Passed:${RESET}   $PASSED_CHECKS / $TOTAL_CHECKS"
    echo -e "  ${YELLOW}Warnings:${RESET} $WARNED_CHECKS"
    echo -e "  ${RED}Failed:${RESET}  $FAILED_CHECKS"
    echo ""

    if [ $FAILED_CHECKS -eq 0 ]; then
        if [ $WARNED_CHECKS -eq 0 ]; then
            echo -e "${GREEN}${BOLD}✅ ALL COMPONENTS VALIDATED SUCCESSFULLY${RESET}"
            exit 0
        else
            echo -e "${YELLOW}${BOLD}⚠️  VALIDATION COMPLETED WITH WARNINGS${RESET}"
            exit 0
        fi
    else
        echo -e "${RED}${BOLD}❌ VALIDATION FAILED - $FAILED_CHECKS ERRORS FOUND${RESET}"
        exit 1
    fi
}

# Run main function
main
