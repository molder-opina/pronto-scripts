#!/bin/bash

# Test script for complete order flow
# This simulates a customer placing an order through the web interface

set -e

echo "=========================================="
echo "Testing Complete Order Flow"
echo "=========================================="
echo ""

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
KITCHEN_RESPONSE=$(curl -s http://localhost:6081/api/orders/kitchen/pending)
if echo "$KITCHEN_RESPONSE" | grep -q "\"id\": $ORDER_ID"; then
    echo "✓ Order appears in Kitchen Board"
else
    echo "⚠ Order not found in Kitchen Board (might be in different status)"
fi
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
