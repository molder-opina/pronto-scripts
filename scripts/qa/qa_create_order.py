import json
import urllib.request

BASE_URL = "http://localhost:6080/api"


def create_order(payload):
    url = f"{BASE_URL}/orders"
    headers = {"Content-Type": "application/json"}
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")

    try:
        with urllib.request.urlopen(req) as response:
            status = response.getcode()
            response_body = response.read().decode("utf-8")
            print(f"Status Code: {status}")
            print("Response:", json.dumps(json.loads(response_body), indent=2))
            return status == 201
    except urllib.request.HTTPError as e:
        print(f"Status Code: {e.code}")
        print("Response:", e.read().decode("utf-8"))
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False


# Test Case 2: Valid Order with ALL modifiers
print("\n--- TEST CASE 2: Valid Order ---")
payload_valid = {
    "table_number": "Mesa 1",  # Should map to M-M01
    "customer": {"name": "QA Final User", "email": "luartx@gmail.com", "phone": "5555555555"},
    "items": [
        {
            "menu_item_id": 1,
            "quantity": 1,
            "modifiers": [
                {"modifier_id": 33, "quantity": 1},  # Coca-Cola
                {"modifier_id": 41, "quantity": 1},  # Papas Fritas
                {"modifier_id": 47, "quantity": 1},  # Salsa Ranch
            ],
        }
    ],
}
success = create_order(payload_valid)

if success:
    print("\n✅ Order created successfully!")
else:
    print("\n❌ Failed to create valid order.")
