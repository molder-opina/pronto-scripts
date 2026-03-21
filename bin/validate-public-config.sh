#!/bin/bash
# Validate /api/public/config endpoint manually
# Usage: ./pronto-scripts/bin/validate-public-config.sh

set -e

ENDPOINT="http://localhost:6082/api/public/config"
OUTPUT_FILE="/tmp/config-backend.json"

echo "🔍 Validating $ENDPOINT..."

# 1. Fetch config
echo "📥 Fetching config..."
if ! curl -s "$ENDPOINT" | jq '.' > "$OUTPUT_FILE" 2>/dev/null; then
    echo "❌ Failed to fetch config. Is the backend running?"
    exit 1
fi

echo "✅ Config fetched successfully"

# 2. Validate structure
echo "📋 Validating structure..."

# Check ui_config exists
if ! jq -e '.ui_config' "$OUTPUT_FILE" > /dev/null; then
    echo "❌ Missing ui_config"
    exit 1
fi

# Check version
VERSION=$(jq -r '.ui_config.version' "$OUTPUT_FILE")
echo "   Version: $VERSION"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]{4}$ ]]; then
    echo "❌ Invalid version format. Expected X.YYYY, got $VERSION"
    exit 1
fi

# Check constraints.auth
if ! jq -e '.ui_config.constraints.auth' "$OUTPUT_FILE" > /dev/null; then
    echo "❌ Missing constraints.auth"
    exit 1
fi

# Check console_scopes
CONSOLE_SCOPES=$(jq -r '.ui_config.constraints.auth.console_scopes | length' "$OUTPUT_FILE")
echo "   Console scopes: $CONSOLE_SCOPES"
if [ "$CONSOLE_SCOPES" -lt 1 ]; then
    echo "❌ console_scopes is empty"
    exit 1
fi

# Check login_roles
LOGIN_ROLES=$(jq -r '.ui_config.constraints.auth.login_roles | length' "$OUTPUT_FILE")
echo "   Login roles: $LOGIN_ROLES"
if [ "$LOGIN_ROLES" -lt 1 ]; then
    echo "❌ login_roles is empty"
    exit 1
fi

# Check allowed_scopes_by_role
ALLOWED_SCOPES=$(jq -r '.ui_config.constraints.auth.allowed_scopes_by_role | keys | length' "$OUTPUT_FILE")
echo "   Allowed scopes by role: $ALLOWED_SCOPES"

# Check constraints.orders
if ! jq -e '.ui_config.constraints.orders' "$OUTPUT_FILE" > /dev/null; then
    echo "❌ Missing constraints.orders"
    exit 1
fi

# Check terminal_statuses
TERMINAL_STATUSES=$(jq -r '.ui_config.constraints.orders.terminal_statuses | length' "$OUTPUT_FILE")
echo "   Terminal statuses: $TERMINAL_STATUSES"
if [ "$TERMINAL_STATUSES" -lt 1 ]; then
    echo "❌ terminal_statuses is empty"
    exit 1
fi

# Check workflow.groups NO existe (migrated to orders)
WORKFLOW_GROUPS=$(jq -r '.ui_config.constraints.workflow.groups // empty' "$OUTPUT_FILE")
if [ -n "$WORKFLOW_GROUPS" ]; then
    echo "⚠️  WARNING: workflow.groups still exists (should be migrated to constraints.orders)"
fi

# 3. Validate debug_email (should be null in prod)
PRONTO_ENV="${PRONTO_ENV:-prod}"
echo "   Environment: $PRONTO_ENV"

DEBUG_EMAILS=$(jq -r '.ui_config.constraints.auth.login_roles[].ui.debug_email' "$OUTPUT_FILE" | grep -v null || true)
if [ "$PRONTO_ENV" = "prod" ] && [ -n "$DEBUG_EMAILS" ]; then
    echo "⚠️  WARNING: debug_email should be null in production"
fi

echo ""
echo "✅ All validations passed!"
echo ""
echo "📄 Sample output:"
echo "---"
jq '.ui_config.constraints.auth.console_scopes' "$OUTPUT_FILE"
jq '.ui_config.constraints.orders.terminal_statuses' "$OUTPUT_FILE"
echo "---"
echo ""
echo "💡 Full output saved to: $OUTPUT_FILE"
