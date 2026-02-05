import http.cookiejar
import json
import sys
import urllib.parse
import urllib.request

BASE_EMPLOYEE_URL = "http://localhost:6081/api"
SESSION_ID = 422  # Using the active session
LOGIN_EMAIL = "admin@cafeteria.test"
LOGIN_PASS = "ChangeMe!123"

# Setup Cookie Jar
cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))


def api_call(endpoint, payload=None, method="POST"):
    url = f"{BASE_EMPLOYEE_URL}{endpoint}"
    headers = {"Content-Type": "application/json"}
    data = json.dumps(payload).encode("utf-8") if payload else None

    print(f"[{method}] {endpoint}...")
    try:
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        with opener.open(req) as response:
            status = response.getcode()
            response_body = response.read().decode("utf-8")
            print(f"Status: {status}")
            return json.loads(response_body)
    except urllib.request.HTTPError as e:
        print(f"Status: {e.code}")
        print("Error:", e.read().decode("utf-8"))
        return None
    except Exception as e:
        print(f"Exception: {e}")
        return None


# 1. Login
print("\n--- 1. Logging in ---")
if api_call("/auth/login", {"email": LOGIN_EMAIL, "password": LOGIN_PASS}):
    print("✅ Login successful")
else:
    print("❌ Login failed")
    # PLR1722: Use `sys.exit()`
    sys.exit(1)

# 2. Confirm Payment (Required for Cash)
print("\n--- 2. Confirming Payment ---")
if api_call(f"/sessions/{SESSION_ID}/confirm-payment", {}):
    print("✅ Payment confirmed (Session Closed)")
else:
    print("❌ Payment confirmation failed")

# 3. Resend Email (Paid Tab check)
print("\n--- 3. Resending Email (Paid Tab check) ---")
resend_payload = {"email": "luartx@gmail.com"}
res = api_call(f"/sessions/{SESSION_ID}/resend", resend_payload)
if res:
    print("✅ Email resend triggered successfully")
    print(res)
else:
    print("❌ Email resend failed")

# 4. Check Paid Recent List (Paid Tab view)
print("\n--- 4. Checking Paid Recent List ---")
paid_resp = api_call("/orders?status=paid&paid_recent_minutes=120", None, method="GET")
if paid_resp:
    payload = paid_resp.get("data", paid_resp)
    orders = payload.get("orders") or payload.get("data") or []
    session_ids = sorted({int(o.get("session_id")) for o in orders if o.get("session_id")})
    if SESSION_ID in session_ids:
        print(f"✅ Session {SESSION_ID} found in paid_recent derived list")
    else:
        print(f"❌ Session {SESSION_ID} NOT found. Found IDs: {session_ids}")

    # Invariant: paid => paid_at not null
    missing_paid_at = [
        o.get("id")
        for o in orders
        if str(o.get("workflow_status")) == "paid" and not o.get("paid_at")
    ]
    if missing_paid_at:
        print(f"❌ Invariant failed: paid_at missing for orders: {missing_paid_at}")
        sys.exit(2)
    print("✅ Invariant OK: all paid orders have paid_at")
else:
    print("❌ Failed to fetch orders for paid_recent check")
