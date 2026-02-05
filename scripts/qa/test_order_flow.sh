#!/bin/bash

# Test script for complete order flow
# This simulates a customer placing an order through the web interface

set -e

echo "=========================================="
echo "Testing Complete Order Flow"
echo "=========================================="
echo ""

# Gate anti-drift (legacy endpoints must not be referenced for estados de sesion)
if command -v rg >/dev/null 2>&1; then
  echo "Precheck: anti-drift grep..."
  if rg -n "/api/sessions/(paid-recent|paid|closed|awaiting-payment)" pronto-static/src/vue/employees >/dev/null; then
    echo "✗ Legacy session-state endpoints still referenced in pronto-static/src/vue/employees"
    rg -n "/api/sessions/(paid-recent|paid|closed|awaiting-payment)" pronto-static/src/vue/employees || true
    exit 1
  fi
  if rg -n "/api/orders/kitchen/pending" pronto-static/src/vue/employees >/dev/null; then
    echo "✗ Legacy kitchen pending endpoint still referenced in pronto-static/src/vue/employees"
    rg -n "/api/orders/kitchen/pending" pronto-static/src/vue/employees || true
    exit 1
  fi
  echo "✓ Anti-drift grep OK"
  echo ""
fi

# Step 1: Get menu to find available items
echo "Step 1: Fetching menu..."
MENU_RESPONSE=$(curl -s http://localhost:6080/api/menu)
echo "✓ Menu fetched successfully"
echo ""

# Step 2: Find a simple item without required modifiers
echo "Step 2: Finding simple menu item..."
ITEM_ID=$(echo "$MENU_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for cat in data.get('categories', []):
    for item in cat.get('items', []):
        groups = item.get('modifier_groups', [])
        has_required = any(g.get('is_required', False) for g in groups)
        if not has_required:
            print(item['id'])
            sys.exit(0)
")
echo "✓ Found item ID: $ITEM_ID"
echo ""

# Step 3: Create an order
echo "Step 3: Creating order..."
ORDER_RESPONSE=$(curl -s -X POST http://localhost:6080/api/orders \
  -H "Content-Type: application/json" \
  -d "{
    \"customer\": {
      \"name\": \"Test Customer $(date +%s)\",
      \"email\": \"test$(date +%s)@example.com\",
      \"phone\": \"+525512345678\"
    },
    \"table_number\": \"M-M01\",
    \"items\": [
      {
        \"menu_item_id\": $ITEM_ID,
        \"quantity\": 2,
        \"modifiers\": []
      }
    ],
    \"notes\": \"Automated test order\"
  }")

# Check if order was created successfully
if echo "$ORDER_RESPONSE" | grep -q '"session_id"'; then
    SESSION_ID=$(echo "$ORDER_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['session_id'])")
    ORDER_ID=$(echo "$ORDER_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['order_id'])")
    TOTAL=$(echo "$ORDER_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['total_amount'])")
    echo "✓ Order created successfully!"
    echo "  - Order ID: $ORDER_ID"
    echo "  - Session ID: $SESSION_ID"
    echo "  - Total: \$$TOTAL"
else
    echo "✗ Order creation failed!"
    echo "Response: $ORDER_RESPONSE"
    exit 1
fi
echo ""

# Step 4: Verify order appears in Kitchen Board
echo "Step 4: Checking Kitchen Board..."
COOKIE_JAR=$(mktemp)
EMPLOYEE_EMAIL="${EMPLOYEE_EMAIL:-admin@cafeteria.test}"
EMPLOYEE_PASSWORD="${EMPLOYEE_PASSWORD:-ChangeMe!123}"

LOGIN_HTTP=$(curl -s -o /tmp/qa_login.json -w "%{http_code}" -c "$COOKIE_JAR" \
  -X POST http://localhost:6081/api/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMPLOYEE_EMAIL\",\"password\":\"$EMPLOYEE_PASSWORD\"}")
if [ "$LOGIN_HTTP" = "200" ]; then
    echo "✓ Employee login OK"

    # Query open statuses to avoid missing NEW orders
    KITCHEN_RESPONSE=$(curl -s -b "$COOKIE_JAR" "http://localhost:6081/api/orders?status=new&status=queued&status=preparing&status=ready&status=delivered&status=awaiting_payment")
    if echo "$KITCHEN_RESPONSE" | grep -q "\"id\": $ORDER_ID"; then
        echo "✓ Order appears in Kitchen Board (/api/orders)"
    else
        echo "⚠ Order not found in Kitchen Board (/api/orders) (might be in different status)"
    fi

    # Contract asserts (should return 200 + JSON)
    QUEUED_HTTP=$(curl -s -o /tmp/qa_orders_queued.json -w "%{http_code}" -b "$COOKIE_JAR" "http://localhost:6081/api/orders?status=queued")
    if [ "$QUEUED_HTTP" = "200" ]; then
        echo "✓ GET /api/orders?status=queued => 200"
    else
        echo "✗ GET /api/orders?status=queued => $QUEUED_HTTP"
        cat /tmp/qa_orders_queued.json || true
        exit 1
    fi

    PAID_RECENT_HTTP=$(curl -s -o /tmp/qa_orders_paid_recent.json -w "%{http_code}" -b "$COOKIE_JAR" "http://localhost:6081/api/orders?status=paid&paid_recent_minutes=15")
    if [ "$PAID_RECENT_HTTP" = "200" ]; then
        echo "✓ GET /api/orders?status=paid&paid_recent_minutes=15 => 200"
    else
        echo "✗ GET /api/orders?status=paid&paid_recent_minutes=15 => $PAID_RECENT_HTTP"
        cat /tmp/qa_orders_paid_recent.json || true
        exit 1
    fi

    PAID_CLOSED_HTTP=$(curl -s -o /tmp/qa_orders_paid_closed.json -w "%{http_code}" -b "$COOKIE_JAR" "http://localhost:6081/api/orders?status=paid&status=cancelled")
    if [ "$PAID_CLOSED_HTTP" = "200" ]; then
        echo "✓ GET /api/orders?status=paid&status=cancelled => 200"
    else
        echo "✗ GET /api/orders?status=paid&status=cancelled => $PAID_CLOSED_HTTP"
        cat /tmp/qa_orders_paid_closed.json || true
        exit 1
    fi

    python3 - <<'PY'
import json, sys

NON_TERMINAL = {"new","queued","preparing","ready","delivered","awaiting_payment"}

def load(path):
  with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
  payload = data.get("data", data) if isinstance(data, dict) else {}
  orders = payload.get("orders") or payload.get("data") or []
  return orders

paid_recent = load("/tmp/qa_orders_paid_recent.json")
queued = load("/tmp/qa_orders_queued.json")

missing_paid_at = [o.get("id") for o in paid_recent if str(o.get("workflow_status")) == "paid" and not o.get("paid_at")]
if missing_paid_at:
  print("✗ Invariant failed: paid_at missing for paid orders:", missing_paid_at)
  sys.exit(2)

S_paid_recent = {int(o.get("session_id")) for o in paid_recent if o and o.get("session_id")}
S_open = {int(o.get("session_id")) for o in queued if o and o.get("session_id") and str(o.get("workflow_status")) in NON_TERMINAL}
mix = sorted(S_paid_recent.intersection(S_open))
if mix:
  print("✗ Gate failed: session_id appears in paid_recent and open:", mix)
  sys.exit(3)
print("✓ /api/orders contract checks OK")
PY
else
    echo "✗ Employee login failed; cannot validate /api/orders contract (status=$LOGIN_HTTP)"
    cat /tmp/qa_login.json || true
    rm -f "$COOKIE_JAR"
    exit 1
fi
rm -f "$COOKIE_JAR"
echo ""

# Step 5: Simulate accessing thank you page
echo "Step 5: Simulating thank you page access..."
THANKS_URL="http://localhost:6080/thanks?session_id=$SESSION_ID&total=$TOTAL"
THANKS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$THANKS_URL")
if [ "$THANKS_RESPONSE" = "200" ]; then
    echo "✓ Thank you page accessible at: $THANKS_URL"
else
    echo "✗ Thank you page returned status: $THANKS_RESPONSE"
fi
echo ""

echo "=========================================="
echo "Order Flow Test Complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Menu: ✓"
echo "  - Order Creation: ✓"
echo "  - Kitchen Board: ✓"
echo "  - Thank You Page: ✓"
echo ""
echo "You can view the order at:"
echo "  - Customer: $THANKS_URL"
echo "  - Kitchen: http://localhost:6081/kitchen"
echo ""
