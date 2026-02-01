import json
import time
import urllib.request

BASE_URL = "http://localhost:6081/api"
ORDER_ID = 141  # From previous step
EMPLOYEE_ID = 1  # Assuming ID 1 exists (Super Admin/Manager)


def api_call(endpoint, payload=None):
    url = f"{BASE_URL}{endpoint}"
    headers = {"Content-Type": "application/json"}
    data = json.dumps(payload).encode("utf-8") if payload else None

    print(f"Calling {endpoint}...")
    try:
        req = urllib.request.Request(url, data=data, headers=headers, method="POST")
        with urllib.request.urlopen(req) as response:
            status = response.getcode()
            response_body = response.read().decode("utf-8")
            print(f"Status Code: {status}")
            print("Response:", json.dumps(json.loads(response_body), indent=2))
            return True
    except urllib.request.HTTPError as e:
        print(f"Status Code: {e.code}")
        print("Response:", e.read().decode("utf-8"))
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False


print(f"--- Processing Order #{ORDER_ID} ---")

# 1. Waiter Accept
print("\n[WAITER] Accepting Order...")
if api_call(f"/orders/{ORDER_ID}/accept", {"employee_id": EMPLOYEE_ID}):
    time.sleep(1)

    # 2. Chef Start
    print("\n[CHEF] Starting Preparation...")
    if api_call(f"/orders/{ORDER_ID}/kitchen/start", {"employee_id": EMPLOYEE_ID}):
        time.sleep(1)

        # 3. Chef Ready
        print("\n[CHEF] Marking Ready...")
        if api_call(f"/orders/{ORDER_ID}/kitchen/ready", {"employee_id": EMPLOYEE_ID}):
            time.sleep(1)

            # 4. Waiter Deliver
            print("\n[WAITER] Delivering...")
            if api_call(f"/orders/{ORDER_ID}/deliver", {"employee_id": EMPLOYEE_ID}):
                print("\n✅ Order processed successfully through delivery!")
