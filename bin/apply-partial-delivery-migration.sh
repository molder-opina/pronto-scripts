#!/bin/bash
# Script to apply partial delivery migration to the database
# This script executes SQL migrations from the canonical migrations directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."

# Source common functions
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/db-helpers.sh"

log_info "=== APPLY PARTIAL DELIVERY MIGRATION ==="

# Check if already applied
if check_column_exists "order_items" "delivered_quantity"; then
    log_warn "Migration already applied. No changes needed."
    echo "✅ Migration already applied"
    exit 0
fi

log_info "Applying partial delivery migration..."

# Execute the SQL migration file
SQL_FILE="$ROOT_DIR/init/sql/migrations/add_partial_delivery_fields.sql"
if [ ! -f "$SQL_FILE" ]; then
    log_error "SQL migration file not found: $SQL_FILE"
    exit 1
fi

execute_sql_file "$SQL_FILE"

log_info "Migration completed successfully"
echo ""
echo "✅ Migration applied successfully"
echo ""
echo "Fields added to order_items:"
echo "  - delivered_quantity (INTEGER, default 0)"
echo "  - is_fully_delivered (BOOLEAN, default FALSE)"  
echo "  - delivered_at (TIMESTAMP, nullable)"
echo "  - delivered_by_employee_id (INTEGER, nullable)"
echo ""
echo "Constraints added:"
echo "  - fk_order_items_delivered_by (FK to employees)"
echo "  - chk_delivered_quantity_valid (CHECK delivered_quantity <= quantity)"
echo ""
echo "Indexes created:"
echo "  - ix_order_items_delivered (is_fully_delivered, delivered_at)"