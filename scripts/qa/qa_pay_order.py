import http.cookiejar
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path

BASE_EMPLOYEE_URL = "http://localhost:6081/api"
SESSION_ID = 422  # From previous steps
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
            # F841: Local variable `response_body` is assigned to but never used
            response.read().decode("utf-8")
            print(f"Status: {status}")
            return True
    except urllib.request.HTTPError as e:
        print(f"Status: {e.code}")
        print("Error:", e.read().decode("utf-8"))
        return False
    except Exception as e:
        print(f"Exception: {e}")
        return False


def download_pdf(endpoint, filename):
    url = f"{BASE_EMPLOYEE_URL}{endpoint}"
    print(f"[GET] Downloading PDF from {endpoint}...")
    try:
        req = urllib.request.Request(url, method="GET")
        with opener.open(req) as response:
            if response.getcode() == 200:
                # PTH123: `open()` should be replaced by `Path.open()`
                pdf_path = Path(filename)
                with pdf_path.open("wb") as f:
                    f.write(response.read())
                print(f"✅ PDF saved to {filename}")
                return True

            print(f"❌ Failed to download PDF. Status: {response.getcode()}")
            return False
    except Exception as e:
        print(f"Exception downloading PDF: {e}")
        return False


# 1. Login
print("\n--- 1. Logging in ---")
if api_call("/auth/login", {"email": LOGIN_EMAIL, "password": LOGIN_PASS}):
    print("✅ Login successful")
else:
    print("❌ Login failed")
    # PLR1722: Use `sys.exit()` instead of `exit`
    sys.exit(1)

# 2. Checkout
print("\n--- 2. Requesting Checkout ---")
if api_call(f"/sessions/{SESSION_ID}/checkout", {}):
    print("✅ Checkout requested")
else:
    print("❌ Checkout failed")

# 3. Finalize Payment (Cash)
print("\n--- 3. Finalizing Payment (Cash) ---")
payment_payload = {"payment_method": "cash", "tip_amount": 5.0}
if api_call(f"/sessions/{SESSION_ID}/pay", payment_payload):
    print("✅ Payment successful")
else:
    print("❌ Payment failed")

# 4. Download PDF
print("\n--- 4. Verifying PDF Ticket ---")
download_pdf(f"/sessions/{SESSION_ID}/ticket.pdf", "ticket_test.pdf")

# 5. Verify Email (Mock verification)
# In a real scenario we'd check logs or mailhog. Here we assume success if no error.
print("\n--- 5. Payment & Ticket Verification ---")
print("Check logs to confirm email sending.")
