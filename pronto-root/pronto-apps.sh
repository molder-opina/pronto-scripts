#!/usr/bin/env bash
#
# PRONTO Apps Management Script (root workspace)
# Manages: static, api, client, employees (docker compose)
#
# Usage:
#   ./pronto-apps.sh up [service]       Start apps (default: all)
#   ./pronto-apps.sh down              Stop all services
#   ./pronto-apps.sh restart [service] Restart (default: all)
#   ./pronto-apps.sh rebuild [service] Rebuild and restart (default: all)
#   ./pronto-apps.sh logs [service]    Tail logs (default: all)
#   ./pronto-apps.sh status            Show status
#   ./pronto-apps.sh pull              Pull repos and rebuild (best-effort)
#   ./pronto-apps.sh infra <cmd>       Manage postgres/redis only
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Services
APPS=("static" "api" "client" "employees")
INFRA=("postgres" "redis")

# Ports
PORTS_STATIC="9088"
PORTS_API="6082"
PORTS_CLIENT="6080"
PORTS_EMPLOYEES="6081"

log_info() { echo "[INFO] $1"; }
log_success() { echo "[SUCCESS] $1"; }
log_warn() { echo "[WARN] $1"; }
log_error() { echo "[ERROR] $1" 1>&2; }

print_header() {
    echo ""
    echo "========================================"
    echo "  PRONTO Apps Management"
    echo "========================================"
    echo ""
}

print_status() {
    echo ""
    echo "Service Status:"
    echo "----------------------------------------"

    for app in "${APPS[@]}"; do
        eval port="\${PORTS_${app^^}}"
        if docker compose --profile apps ps --status running -q "$app" >/dev/null 2>&1; then
            status="RUNNING"
        else
            status="STOPPED"
        fi
        printf "  %-12s | Port %-5s | %s\n" "$app" "$port" "$status"
    done

    echo ""
    echo "Infrastructure:"
    echo "----------------------------------------"
    for infra in "${INFRA[@]}"; do
        if docker compose ps --status running -q "$infra" >/dev/null 2>&1; then
            status="RUNNING"
        else
            status="STOPPED"
        fi
        printf "  %-12s | %s\n" "$infra" "$status"
    done
    echo ""
}

cmd_up() {
    print_header
    log_info "Starting PRONTO applications..."

    local service="${2:-}"
    if [ -n "$service" ]; then
        docker compose --profile apps up -d postgres redis "$service"
    else
        docker compose --profile apps up -d
    fi

    log_info "Waiting for infrastructure..."
    sleep 5

    log_success "All services started!"
    print_status
}

cmd_down() {
    print_header
    log_info "Stopping PRONTO applications..."
    docker compose down
    log_success "All applications stopped."
}

cmd_restart() {
    print_header
    local service="${2:-}"
    if [ -n "$service" ]; then
        docker compose --profile apps restart "$service"
    else
        cmd_down
        sleep 2
        cmd_up
    fi
}

cmd_rebuild() {
    print_header
    log_info "Rebuilding all applications..."
    local service="${2:-}"
    if [ -n "$service" ]; then
        docker compose build --no-cache "$service"
        docker compose --profile apps up -d postgres redis "$service"
    else
        docker compose build --no-cache
        docker compose --profile apps up -d
    fi
    log_success "All applications rebuilt and started!"
    print_status
}

cmd_logs() {
    local service="${2:-}"
    if [ -n "$service" ]; then
        docker compose logs -f "$service"
        return
    fi
    docker compose logs -f
}

cmd_status() {
    print_header
    print_status

    echo "URLs:"
    echo "----------------------------------------"
    for app in "${APPS[@]}"; do
        eval port="\${PORTS_${app^^}}"
        echo -e "  http://localhost:${port}  (${app})"
    done
    echo ""
}

cmd_pull() {
    print_header
    log_info "Pulling latest changes from all repositories..."

    repos=("pronto-static" "pronto-api" "pronto-client" "pronto-employees" "pronto-libs")

    for repo in "${repos[@]}"; do
        if [ -d "$repo" ]; then
            log_info "Updating $repo..."
            cd "$repo"
            git pull origin main 2>/dev/null || log_warn "Could not update $repo (non-fatal)"
            cd - > /dev/null
        fi
    done

    log_success "All repositories updated!"
    log_info "Rebuilding applications..."
    cmd_rebuild
}

cmd_infra() {
    case "$2" in
        up)
            docker compose up -d postgres redis
            log_success "Infrastructure started!"
            ;;
        down)
            docker compose stop postgres redis
            log_success "Infrastructure stopped!"
            ;;
        restart)
            docker compose stop postgres redis
            sleep 2
            docker compose up -d postgres redis
            log_success "Infrastructure restarted!"
            ;;
        *)
            echo "Usage: $0 infra [up|down|restart]"
            ;;
    esac
}

cmd_help() {
    print_header
    echo "Usage: $0 <command> [service]"
    echo ""
    echo "Commands:"
    echo "  up        - Start all applications and infrastructure"
    echo "  down      - Stop all applications"
    echo "  restart   - Restart all applications"
    echo "  rebuild   - Rebuild and restart all applications"
    echo "  pull      - Pull latest changes and rebuild"
    echo "  logs      - Show logs (optional: specific service)"
    echo "  status    - Show status of all services"
    echo "  infra     - Manage infrastructure (postgres, redis)"
    echo ""
    echo "Examples:"
    echo "  $0 up                    # Start everything"
    echo "  $0 logs api              # Show API logs"
    echo "  $0 rebuild client        # Rebuild client only"
    echo "  $0 infra restart         # Restart postgres & redis"
    echo ""
}

# Main
case "${1:-help}" in
    up)
        cmd_up "$@"
        ;;
    down)
        cmd_down
        ;;
    restart)
        cmd_restart "$@"
        ;;
    rebuild)
        cmd_rebuild "$@"
        ;;
    pull)
        cmd_pull
        ;;
    logs)
        cmd_logs "$@"
        ;;
    status)
        cmd_status
        ;;
    infra)
        cmd_infra "$@"
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        log_error "Unknown command: ${1:-}"
        cmd_help
        exit 1
        ;;
esac
