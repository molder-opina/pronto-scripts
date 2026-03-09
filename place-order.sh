#!/bin/bash
# Script to place an order in the Pronto system

set -e

# --- Configuration ---
EMPLOYEES_URL="http://localhost:6081"
API_URL="http://localhost:6082"
WAITER_EMAIL="maria@pronto.com"
WAITER_PASSWORD="ChangeMe!123"
COOKIE_JAR="pronto_cookies.txt"
TABLE_ID=1
MENU_ITEM_ID_1=5 # "Chilaquiles Verdes con Pollo"
MENU_ITEM_ID_2=10 # "Café Americano"

# --- Helper Functions ---
info() {
    echo "[INFO] $1"
}

# --- Main Script ---

# 1. Login as waiter to get auth cookies and CSRF token
info "Logging in as waiter: $WAITER_EMAIL"
LOGIN_PAGE_HTML=$(curl -s -c $COOKIE_JAR "${EMPLOYEES_URL}/waiter/login")
CSRF_TOKEN=$(echo "$LOGIN_PAGE_HTML" | grep 'name="csrf-token"' | sed -n 's/.*content="\([^"]*\)".*/\1/p')

if [ -z "$CSRF_TOKEN" ]; then
    echo "[ERROR] Could not get CSRF token from login page."
    exit 1
fi
info "Got CSRF token."

LOGIN_RESPONSE=$(curl -s -X POST -b $COOKIE_JAR -c $COOKIE_JAR -H "X-CSRFToken: $CSRF_TOKEN" -H "Content-Type: application/x-www-form-urlencoded" -H 'X-Requested-With: XMLHttpRequest' -d "email=${WAITER_EMAIL}&password=${WAITER_PASSWORD}" "${EMPLOYEES_URL}/waiter/login")

if ! echo "$LOGIN_RESPONSE" | grep -q "success"; then
    echo "[ERROR] Waiter login failed."
    echo "$LOGIN_RESPONSE"
    exit 1
fi
info "Login successful."

# 2. Create a new dining session
info "Creating a new dining session for table ID: $TABLE_ID"
SESSION_RESPONSE=$(curl -s -X POST -b $COOKIE_JAR -H "Content-Type: application/json" -H "X-CSRFToken: $CSRF_TOKEN" -d "{\"table_id\": $TABLE_ID}" "${API_URL}/api/sessions/open")

if ! command -v jq &> /dev/null
then
    echo "[ERROR] jq is not installed. Please install jq to parse the session ID."
    exit 1
fi

DINING_SESSION_ID=$(echo "$SESSION_RESPONSE" | jq -r '.session.id')

if [ -z "$DINING_SESSION_ID" ] || [ "$DINING_SESSION_ID" == "null" ]; then
    echo "[ERROR] Could not create dining session."
    echo "$SESSION_RESPONSE"
    exit 1
fi
info "Dining session created with ID: $DINING_SESSION_ID"

# 3. Add items to the cart
info "Adding items to the cart..."
# Note: The endpoint for adding items to the cart is part of the 'orders' blueprint, not 'dining-sessions'
ADD_ITEM_1_RESPONSE=$(curl -s -X POST -b $COOKIE_JAR -H "Content-Type: application/json" -H "X-CSRFToken: $CSRF_TOKEN" -d "{\"menu_item_id\": $MENU_ITEM_ID_1, \"quantity\": 1}" "${API_URL}/api/orders/${DINING_SESSION_ID}/items")

ADD_ITEM_2_RESPONSE=$(curl -s -X POST -b $COOKIE_JAR -H "Content-Type: application/json" -H "X-CSRFToken: $CSRF_TOKEN" -d "{\"menu_item_id\": $MENU_ITEM_ID_2, \"quantity\": 1}" "${API_URL}/api/orders/${DINING_SESSION_ID}/items")

info "Items added to cart."

# 4. Confirm the order
info "Confirming the order..."
# Note: The endpoint for confirming the order is also part of the 'orders' blueprint
CONFIRM_RESPONSE=$(curl -s -X POST -b $COOKIE_JAR -H "Content-Type: application/json" -H "X-CSRFToken: $CSRF_TOKEN" "${API_URL}/api/orders/${DINING_SESSION_ID}/confirm")

if ! echo "$CONFIRM_RESPONSE" | grep -q "status"; then
    echo "[ERROR] Order confirmation failed."
    echo "$CONFIRM_RESPONSE"
    exit 1
fi
info "Order confirmed successfully!"
echo "--- Final Order Details ---"
echo "$CONFIRM_RESPONSE" | python -m json.tool

# Clean up cookie jar
rm $COOKIE_JAR
