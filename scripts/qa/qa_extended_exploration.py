import http.cookiejar
import json
import sys
import urllib.parse
import urllib.request
from datetime import datetime

BASE_URL = "http://localhost:6081/api"
LOGIN_EMAIL = "admin@cafeteria.test"
LOGIN_PASS = "ChangeMe!123"

cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))


def api_call(endpoint, payload=None, method="GET"):
    url = f"{BASE_URL}{endpoint}"
    headers = {"Content-Type": "application/json"}
    data = json.dumps(payload).encode("utf-8") if payload else None

    print(f"[{method}] {endpoint}...", end=" ")
    try:
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        with opener.open(req) as response:
            status = response.getcode()
            print(f"✅ ({status})")
            if status != 204:
                return json.loads(response.read().decode("utf-8"))
            return {}
    except urllib.request.HTTPError as e:
        print(f"❌ ({e.code}) - {e.read().decode('utf-8')}")
        return None
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return None


# 1. Login
if not api_call("/auth/login", {"email": LOGIN_EMAIL, "password": LOGIN_PASS}, "POST"):
    # PLR1722: Use `sys.exit()` instead of `exit`
    sys.exit(1)


# Helper to unwrap response
def get_data(response):
    if response and "data" in response:
        return response["data"]
    return response


print("\n--- 🛒 MENU MANAGEMENT ---")
menu_response = api_call("/menu")
menu = get_data(menu_response)
if menu:
    # It might be a list or dict depending on implementation
    count = len(menu) if isinstance(menu, list) else len(menu.get("categories", []))
    print(f"   ✅ Found {count} categories/items.")
else:
    print(f"   ❌ Failed to list menu structure: {menu_response}")

print("\n--- 👥 EMPLOYEES ---")
emps_response = api_call("/employees")
emps = get_data(emps_response)
if emps:
    # Usually list or dict with 'employees' key
    count = len(emps) if isinstance(emps, list) else len(emps.get("employees", []))
    print(f"   ✅ Found {count} employees.")

print("\n--- 🎫 DISCOUNT CODES ---")
# Try creating a discount code
code = f"QA{datetime.now().strftime('%H%M%S')}"
discount_payload = {
    "code": code,
    "discount_type": "percentage",
    "discount_percentage": 10,  # Correct field name
    "description": "QA Auto Discount",
    "is_active": True,
    "min_order_amount": 0,
    "max_discount_amount": 100,
}
# Check if creating works (endpoint usually /discount-codes)
res = api_call("/discount-codes", discount_payload, "POST")
if res:
    print(f"   ✅ Created Discount Code: {code}")
else:
    print("   ⚠️ Discount creation failed (Check logs/routes)")

print("\n--- ⚙️ CONFIG ---")
# Get public config
config = api_call("/config/public")
if config:
    print("   ✅ Public config retrieval success.")

print("\n--- 📊 ANALYTICS START ---")
# Fetch KPI
api_call("/analytics/kpis")
api_call("/analytics/revenue-trends")
api_call("/analytics/operational-metrics")

print("\n--- ✅ EXPLORATION COMPLETE ---")
