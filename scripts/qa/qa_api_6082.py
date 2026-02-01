import http.cookiejar
import json
import urllib.request

BASE_URL = "http://localhost:6082"
LOGIN_EMAIL = "admin@cafeteria.test"
LOGIN_PASS = "ChangeMe!123"

# Cookie Jar for Auth
cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))


def api_call(endpoint, method="GET", payload=None):
    url = f"{BASE_URL}{endpoint}"
    data = json.dumps(payload).encode("utf-8") if payload else None
    headers = {"Content-Type": "application/json"}

    print(f"[{method}] {url}...", end=" ")
    try:
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        with opener.open(req) as response:
            status = response.getcode()
            print(f"✅ ({status})")
            return json.loads(response.read().decode("utf-8"))
    except urllib.request.HTTPError as e:
        print(f"❌ ({e.code}) - {e.read().decode('utf-8')}")
        return None
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return None


print("--- TESTING API GATEWAY (6082) ---")

# 1. Health
api_call("/health")

# 2. Client API Proxy
print("\n--- Client API Route ---")
menu = api_call("/api/client/menu")
if menu:
    data = menu.get("data", menu)
    cats = data.get("categories", []) if isinstance(data, dict) else []
    print(f"   Found {len(cats)} categories via Public API.")

# 3. Employee API Proxy (Protected)
print("\n--- Employee API Route (With Auth) ---")
# Authenticate first
print("   Logging in via Gateway...")
# Try logging in via Employee API through Gateway
# Does /api/employee/auth/login exist? Yes, proxied.
login_res = api_call(
    "/api/employee/auth/login",
    method="POST",
    payload={"email": LOGIN_EMAIL, "password": LOGIN_PASS},
)

if login_res:
    # Now check Tables
    api_call("/api/employee/tables")
else:
    print("   ⚠️ Login failed, skipping tables check.")
