#!/usr/bin/env bash

# financial_guard.sh
# Pre-commit agent to enforce strict financial invariants and State Machine usage.

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

function fail() {
  echo -e "${RED}[FAIL] $1${NC}"
  exit 1
}

echo "Running Financial Guard Checks..."

# 1. Block direct `.status = ` mutations for dining sessions
# Using a regex that captures dining_session.status = 
# We should allow mark_status or apply_event, but = is banned.
STATUS_VIOLATIONS=$(grep -RnEE "dining_session\.status\s*=[^=]" pronto-libs/src pronto-api/src pronto-employees/src pronto-client/src | grep -v "test" | grep -v "fixture" || true)

if [ ! -z "$STATUS_VIOLATIONS" ]; then
  echo "$STATUS_VIOLATIONS"
  fail "Direct mutation of dining_session.status detected! Use SessionStateMachine.apply_event() instead."
fi

# 2. Block direct Payment( creations outside finalize_payment and external_payment_success
PAYMENT_VIOLATIONS=$(grep -Rn "Payment(" pronto-libs/src pronto-api/src pronto-employees/src pronto-client/src \
  | grep -v "finalize_payment" \
  | grep -v "confirm_external_payment_success" \
  | grep -v "test" \
  | grep -v "fixture" \
  | grep -v "models/" || true)

if [ ! -z "$PAYMENT_VIOLATIONS" ]; then
  echo "$PAYMENT_VIOLATIONS"
  fail "Direct Payment() instantiation detected outside authorized use cases!"
fi

# 3. Block manual recalculations of total_paid
TOTAL_PAID_VIOLATIONS=$(grep -RnEE "\.total_paid\s*(\+|\-)?=[^=]" pronto-libs/src pronto-api/src pronto-employees/src pronto-client/src \
  | grep -v "session_financial_service.py" \
  | grep -v "test" \
  | grep -v "fixture" || true)

if [ ! -z "$TOTAL_PAID_VIOLATIONS" ]; then
  echo "$TOTAL_PAID_VIOLATIONS"
  fail "Manual accumulation of total_paid detected! Use sync_session_financials() in payments domain."
fi

# 4. Block manual remaining_amount assignments
REMAINING_VIOLATIONS=$(grep -RnEE "\.remaining_amount\s*(\+|\-)?=[^=]" pronto-libs/src pronto-api/src pronto-employees/src pronto-client/src \
  | grep -v "test" \
  | grep -v "fixture" || true)

if [ ! -z "$REMAINING_VIOLATIONS" ]; then
  echo "$REMAINING_VIOLATIONS"
  fail "Manual remaining_amount logic detected! Balance must be calculated dynamically."
fi

# 5. Block sync_session_financials outside authorized use cases
SYNC_VIOLATIONS=$(grep -Rn "sync_session_financials(" pronto-libs/src pronto-api/src pronto-employees/src pronto-client/src --exclude="*.pyc" \
  | grep -v "finalize_payment.py" \
  | grep -v "confirm_external_payment_success.py" \
  | grep -v "confirm_payment.py" \
  | grep -v "payment_domain.py" \
  | grep -v "recompute_financials.py" \
  | grep -v "transition_order_state.py" \
  | grep -v "order_cancel.py" \
  | grep -v "order_payment.py" \
  | grep -v "session_financial_service.py" \
  | grep -v "dining_session_service_impl.py" \
  | grep -v "seed.py" \
  | grep -v "test" \
  | grep -v "fixture" || true)

if [ ! -z "$SYNC_VIOLATIONS" ]; then
  echo "$SYNC_VIOLATIONS"
  fail "Direct sync_session_financials() call detected outside of authorized payment/order flow contexts!"
fi

echo -e "${GREEN}[OK] Financial Guard Checks Passed${NC}"
exit 0
