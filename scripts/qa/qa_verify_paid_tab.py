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
paid_list = api_call("/sessions/paid-recent", None, method="GET")
if paid_list and "sessions" in paid_list:
    found = any(s["id"] == SESSION_ID for s in paid_list["sessions"])
    if found:
        print(f"✅ Session {SESSION_ID} found in Paid Recent list")
    else:
        print(
            f"❌ Session {SESSION_ID} NOT found in Paid Recent list. Found IDs: {[s['id'] for s in paid_list['sessions']]}"
        )
else:
    print("❌ Failed to fetch Paid Recent list")
