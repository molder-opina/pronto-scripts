#!/bin/bash
# Deploy Maintenance Page to Server
# Usage: ./bin/deploy-maintenance.sh [enable|disable|deploy]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MAINTENANCE_DIR="/var/www/maintenance"
ENABLE_FILE="$MAINTENANCE_DIR/enable"

# Functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
}

deploy_maintenance_page() {
    print_info "Deploying maintenance page..."

    # Create directory structure
    mkdir -p "$MAINTENANCE_DIR/maintenance-assets"

    # Copy maintenance page
    local maintenance_source="${MAINTENANCE_SOURCE:-build/static_content/maintenance.html}"
    if [ -f "$maintenance_source" ]; then
        cp "$maintenance_source" "$MAINTENANCE_DIR/maintenance.html"
        print_info "Copied maintenance.html from $maintenance_source"
    else
        print_error "Maintenance page not found at $maintenance_source"
        exit 1
    fi

    # Set permissions
    chown -R www-data:www-data "$MAINTENANCE_DIR"
    chmod -R 755 "$MAINTENANCE_DIR"

    print_info "Maintenance page deployed successfully to $MAINTENANCE_DIR"
}

enable_maintenance() {
    print_warn "Enabling maintenance mode..."

    if [ ! -f "$MAINTENANCE_DIR/maintenance.html" ]; then
        print_error "Maintenance page not deployed yet. Run: $0 deploy"
        exit 1
    fi

    # Create enable file
    touch "$ENABLE_FILE"

    # Test Nginx config
    if nginx -t >/dev/null 2>&1; then
        # Reload Nginx
        systemctl reload nginx
        print_info "✅ Maintenance mode ENABLED"
        print_info "Site will show maintenance page"
        print_info "To disable: $0 disable"
    else
        print_error "Nginx configuration test failed"
        rm -f "$ENABLE_FILE"
        exit 1
    fi
}

disable_maintenance() {
    print_info "Disabling maintenance mode..."

    # Remove enable file
    if [ -f "$ENABLE_FILE" ]; then
        rm -f "$ENABLE_FILE"
        systemctl reload nginx
        print_info "✅ Maintenance mode DISABLED"
        print_info "Site is back to normal operation"
    else
        print_warn "Maintenance mode was not enabled"
    fi
}

check_status() {
    print_info "Checking maintenance mode status..."
    echo ""

    if [ -f "$ENABLE_FILE" ]; then
        echo -e "${RED}🔧 MAINTENANCE MODE: ENABLED${NC}"
        echo "Site is showing maintenance page"
    else
        echo -e "${GREEN}✅ MAINTENANCE MODE: DISABLED${NC}"
        echo "Site is operating normally"
    fi

    echo ""
    print_info "Checking services..."

    # Check if ports are listening
    for port in 6080 6081 9088; do
        if ss -tuln | grep -q ":$port "; then
            echo -e "  Port $port: ${GREEN}✅ ACTIVE${NC}"
        else
            echo -e "  Port $port: ${RED}❌ INACTIVE${NC}"
        fi
    done

    echo ""
    print_info "Recent Nginx errors (last 10 lines):"
    if [ -f "/var/log/nginx/pronto_error.log" ]; then
        tail -n 10 /var/log/nginx/pronto_error.log | grep -i "503\|502\|504\|upstream" || echo "  No recent errors"
    else
        echo "  Log file not found"
    fi
}

test_maintenance() {
    print_info "Testing maintenance page..."

    if [ ! -f "$MAINTENANCE_DIR/maintenance.html" ]; then
        print_error "Maintenance page not found. Run: $0 deploy"
        exit 1
    fi

    # Temporarily enable maintenance
    touch "$ENABLE_FILE"

    # Test with curl
    print_info "Testing with curl..."
    response=$(curl -k -s -o /dev/null -w "%{http_code}" https://localhost/check-maintenance)

    if [ "$response" == "503" ]; then
        print_info "✅ Maintenance endpoint returns 503 (correct)"
    else
        print_warn "Maintenance endpoint returns $response (expected 503)"
    fi

    # Cleanup
    rm -f "$ENABLE_FILE"

    print_info "Test completed. Maintenance mode was NOT left enabled."
}

show_usage() {
    cat << EOF
Usage: $0 [command]

Commands:
    deploy      Deploy/update maintenance page files
    enable      Enable maintenance mode (show maintenance page)
    disable     Disable maintenance mode (restore normal operation)
    status      Check current maintenance mode status
    test        Test maintenance page without enabling it
    help        Show this help message

Examples:
    # First time setup
    sudo $0 deploy

    # Before deployment
    sudo $0 enable

    # After deployment
    sudo $0 disable

    # Check status
    sudo $0 status

EOF
}

# Main script logic
case "${1:-help}" in
    deploy)
        check_root
        deploy_maintenance_page
        ;;
    enable)
        check_root
        enable_maintenance
        ;;
    disable)
        check_root
        disable_maintenance
        ;;
    status)
        check_root
        check_status
        ;;
    test)
        check_root
        test_maintenance
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac

exit 0
