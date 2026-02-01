#!/bin/bash
# =============================================================================
# COMPONENT VALIDATOR SCRIPT
# Validates that all required system components are working correctly
# =============================================================================
#
# Usage:
#   ./bin/validate-components.sh [--quick] [--verbose] [--fix]
#
# =============================================================================

set -e

RED='\033[91m'
GREEN='\033[92m'
YELLOW='\033[93m'
BLUE='\033[94m'
BOLD='\033[1m'
RESET='\033[0m'

VERBOSE=false
QUICK=false
FIX=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --quick) QUICK=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        --fix) FIX=true; shift ;;
        *) shift ;;
    esac
done

log_info() { echo -e "${BLUE}[INFO]${RESET} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${RESET} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_fail() { echo -e "${RED}[FAIL]${RESET} $1"; }
log_section() { echo ""; echo -e "${BOLD}${BLUE}=== $1 ===${RESET}"; }

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNED_CHECKS=0

check_docker_services() {
    log_section "Docker Services"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if docker info >/dev/null 2>&1; then
        log_pass "Docker is running"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_fail "Docker is not running"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi

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
        fi
    done
}

check_ports() {
    log_section "Port Accessibility"

    # Web services accessible from host
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:6080" 2>/dev/null)
    if [ "$status_code" = "200" ]; then
        log_pass "Port 6080 (Client) - accessible (HTTP $status_code)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_fail "Port 6080 (Client) - NOT accessible (HTTP $status_code)"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:6081" 2>/dev/null)
    if [ "$status_code" = "200" ]; then
        log_pass "Port 6081 (Employee) - accessible (HTTP $status_code)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_fail "Port 6081 (Employee) - NOT accessible (HTTP $status_code)"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:9088" 2>/dev/null)
    if [ "$status_code" = "200" ] || [ "$status_code" = "404" ]; then
        log_pass "Port 9088 (Static) - accessible (HTTP $status_code)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_fail "Port 9088 (Static) - NOT accessible (HTTP $status_code)"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    # Docker-internal ports
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if docker exec pronto-postgres psql -U pronto -d pronto -c "SELECT 1;" >/dev/null 2>&1; then
        log_pass "PostgreSQL - accessible via Docker"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_warn "PostgreSQL - internal Docker port"
        WARNED_CHECKS=$((WARNED_CHECKS + 1))
    fi

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if docker exec pronto-redis redis-cli ping >/dev/null 2>&1; then
        log_pass "Redis - accessible via Docker"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_warn "Redis - internal Docker port"
        WARNED_CHECKS=$((WARNED_CHECKS + 1))
    fi
}

check_api_health() {
    log_section "API Health"

    local endpoints=(
        "http://localhost:6080/api/health:Client API"
        "http://localhost:6081/api/health:Employee API"
    )

    for endpoint_info in "${endpoints[@]}"; do
        local url=$(echo "$endpoint_info" | cut -d':' -f1,2,3)
        local name=$(echo "$endpoint_info" | cut -d':' -f4-)

        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        local status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

        if [ "$status" = "200" ]; then
            log_pass "$name - Healthy (HTTP $status)"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            log_warn "$name - Status: HTTP $status"
            WARNED_CHECKS=$((WARNED_CHECKS + 1))
        fi
    done
}

check_database() {
    log_section "Database"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if PGPASSWORD="pronto123" psql -h localhost -p 5432 -U pronto -d pronto -c "SELECT 1;" >/dev/null 2>&1; then
        log_pass "PostgreSQL connection successful"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_fail "PostgreSQL connection failed"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

check_redis() {
    log_section "Redis"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    # Verificar si el contenedor existe
    REDIS_CONTAINER="pronto-redis"
    if ! docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${REDIS_CONTAINER}$"; then
        log_warn "Redis - contenedor no encontrado (no está configurado)"
        WARNED_CHECKS=$((WARNED_CHECKS + 1))
        return 0
    fi

    # Verificar si el contenedor está en ejecución
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${REDIS_CONTAINER}$"; then
        log_warn "Redis - contenedor existe pero está detenido"
        WARNED_CHECKS=$((WARNED_CHECKS + 1))
        return 0
    fi

    # Verificar conectividad
    if docker exec "${REDIS_CONTAINER}" redis-cli ping >/dev/null 2>&1; then
        log_pass "Redis - accessible via Docker"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_fail "Redis - no responde a ping"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

main() {
    echo ""
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${BLUE}║           COMPONENT VALIDATION SCRIPT                      ║${RESET}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""

    check_docker_services

    if [ "$QUICK" = false ]; then
        check_ports
        check_api_health
        check_database
        check_redis
    fi

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
        echo -e "${GREEN}${BOLD}✅ ALL COMPONENTS VALIDATED SUCCESSFULLY${RESET}"
        exit 0
    else
        echo -e "${RED}${BOLD}❌ VALIDATION FAILED${RESET}"
        exit 1
    fi
}

main
