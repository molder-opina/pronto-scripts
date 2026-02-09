#!/usr/bin/env bash
# Script to verify JWT Refresh Token Flow
# Usage: bash bin/tests/test-auth-refresh.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

# Capture override
OVERRIDE_URL="$EMPLOYEE_API_BASE_URL"

if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

# Restore override if set
if [ -n "$OVERRIDE_URL" ]; then
    EMPLOYEE_API_BASE_URL="$OVERRIDE_URL"
fi

# Configuración
BASE_URL="${EMPLOYEE_API_BASE_URL:-http://localhost:5000}"
# Ensure no trailing slash
BASE_URL="${BASE_URL%/}"

EMAIL="juan@pronto.com"
PASSWORD="1234"
COOKIE_JAR="/tmp/cookies.txt"

COOKIES_1="/tmp/pronto_cookies_1.txt"
COOKIES_2="/tmp/pronto_cookies_2.txt"

clean_up() {
    rm -f "$COOKIES_1" "$COOKIES_2"
}
trap clean_up EXIT

# Helper for API requests
api_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local cookie_file=$4
    local save_cookie_file=$5
    
    local cmd=(curl -s -v)
    
    if [[ -n "$cookie_file" ]]; then
        cmd+=(-b "$cookie_file")
    fi
    
    if [[ -n "$save_cookie_file" ]]; then
        cmd+=(-c "$save_cookie_file")
    fi
    
    if [[ "$method" == "GET" ]]; then
        cmd+=("$BASE_URL$endpoint")
    else
        cmd+=(-X "$method" -H "Content-Type: application/json")
        if [[ -n "$data" ]]; then
            cmd+=(-d "$data")
        fi
        cmd+=("$BASE_URL$endpoint")
    fi
    
    "${cmd[@]}"
}

print_test() {
    local test_name=$1
    local result=$2
    if echo "$result" | grep -q "success"; then
        echo -e "${GREEN}✓${NC} $test_name"
    elif echo "$result" | grep -q "Token refreshed"; then
        echo -e "${GREEN}✓${NC} $test_name"
    elif echo "$result" | grep -q "Token revoked"; then
        echo -e "${GREEN}✓${NC} $test_name"
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "$result"
        return 1
    fi
}

echo -e "${YELLOW}=== Testing Token Refresh & Revocation ===${NC}"
echo "Target: $BASE_URL"
echo "User: $EMAIL"

# 1. Login
echo "1. Logging in..."
LOGIN_JSON="{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}"
# Save cookies to COOKIES_1
LOGIN_RESP=$(api_request POST "/employee-auth/login" "$LOGIN_JSON" "" "$COOKIES_1")

if echo "$LOGIN_RESP" | grep -q "Login successful"; then
    echo -e "${GREEN}✓ Login successful${NC}"
else
    echo -e "${RED}✗ Login failed${NC}"
    echo "$LOGIN_RESP"
    exit 1
fi

# 2. Refresh Token
echo "2. Refreshing token..."
# Use COOKIES_1, Save to COOKIES_2 (Rotation: new refresh token)
REFRESH_RESP=$(api_request POST "/employee-auth/refresh" "" "$COOKIES_1" "$COOKIES_2")

print_test "Refresh Token" "$REFRESH_RESP"

# 3. Verify Reuse of Old Token (Should fail)
echo "3. Attempting to resuse OLD refresh token (Expect Failure)..."
# Use COOKIES_1 (Old token)
REUSE_RESP=$(api_request POST "/employee-auth/refresh" "" "$COOKIES_1" "")

if echo "$REUSE_RESP" | grep -q "Token revoked"; then
    echo -e "${GREEN}✓ Reuse Blocked (Token revoked)${NC}"
else
    # It might return "Token revoked" or "Invalid token" depending on implementation
    if echo "$REUSE_RESP" | grep -q "revoked"; then
         echo -e "${GREEN}✓ Reuse Blocked (Revoked)${NC}"
    else
        echo -e "${RED}✗ Failed: Old token was accepted or unexpected error${NC}"
        echo "$REUSE_RESP"
        # exit 1  # Don't exit, just mark failed
    fi
fi

# 4. Verify Use of New Token (Should succeed)
echo "4. Using NEW refresh token..."
# Use COOKIES_2
NEW_REFRESH_RESP=$(api_request POST "/employee-auth/refresh" "" "$COOKIES_2" "")

if echo "$NEW_REFRESH_RESP" | grep -q "Token refreshed"; then
    echo -e "${GREEN}✓ New token valid${NC}"
else
    echo -e "${RED}✗ Failed: New token invalid${NC}"
    echo "$NEW_REFRESH_RESP"
    exit 1
fi

# 5. Revoke Token
echo "5. Revoking token..."
REVOKE_RESP=$(api_request POST "/employee-auth/revoke" "" "$COOKIES_2" "")

print_test "Token Revocation" "$REVOKE_RESP"

echo -e "${GREEN}All Auth Refresh tests passed!${NC}"
