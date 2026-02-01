import sys
import time

import requests

API_CLIENT = "http://localhost:6080"
API_EMPLOYEE = "http://localhost:6081"

# Auth
ADMIN_EMAIL = "admin@cafeteria.test"
ADMIN_PASS = "ChangeMe!123"

session_employee = requests.Session()
session_client = requests.Session()


def print_step(msg):
    print(f"\n[STEP] {msg}")


def check(response, expected_status=200):
    if response.status_code != expected_status:
        print(f"FAILED: Expected {expected_status}, got {response.status_code}")
        try:
            print("Response:", response.json())
        except Exception:
            # Fix E722: Do not use bare `except`
            print("Response:", response.text)
        # PLR1722: Use `sys.exit()` instead of `exit`
        sys.exit(1)
    return response


# ==================== AUTH ====================
print_step("Logging in Employee...")
res = session_employee.post(
    f"{API_EMPLOYEE}/login", data={"email": ADMIN_EMAIL, "password": ADMIN_PASS}, timeout=10
)
if res.status_code != 200:
    print("Login Failed")
    print(res.text)
    sys.exit(1)
print("Login successful (Cookies set)")

# ==================== PRODUCT LIFECYCLE ====================
print_step("Creating QA Product...")
new_product = {
    "name": "QA Burger Auto",
    "price": "123.45",
    "category": "QA Testing",
    "description": "Automated QA Product",
    "image_path": "https://placehold.co/100",
}
res = session_employee.post(f"{API_EMPLOYEE}/api/menu-items", json=new_product, timeout=10)
check(res, 201)
product_data = res.json()
product_id = product_data["id"]
print(f"Created Product ID: {product_id}")

# ==================== ORDER LIFECYCLE ====================
print_step("Creating Client Order...")
new_order = {
    "customer": {"name": "QA Guest", "email": "qa@test.com"},
    "items": [{"menu_item_id": product_id, "quantity": 1, "modifiers": []}],
}
res = session_client.post(f"{API_CLIENT}/api/orders", json=new_order, timeout=10)
check(res, 201)
order_data = res.json()
# Extract Order ID
order_id = order_data.get("id") or order_data.get("order_id")
if not order_id and "order" in order_data:
    order_id = order_data["order"]["id"]
print(f"Created Order ID: {order_id}")

print_step("Accepting Order...")
# Employee ID 1 (Super Admin)
res = session_employee.post(
    f"{API_EMPLOYEE}/api/orders/{order_id}/accept", json={"employee_id": 1}, timeout=10
)
check(res, 200)

print_step("Kitchen Start...")
res = session_employee.post(
    f"{API_EMPLOYEE}/api/orders/{order_id}/kitchen/start", json={"employee_id": 1}, timeout=10
)
check(res, 200)

print_step("Kitchen Ready...")
res = session_employee.post(
    f"{API_EMPLOYEE}/api/orders/{order_id}/kitchen/ready", json={"employee_id": 1}, timeout=10
)
check(res, 200)

print_step("Delivering...")
res = session_employee.post(
    f"{API_EMPLOYEE}/api/orders/{order_id}/deliver", json={"employee_id": 1}, timeout=10
)
check(res, 200)

# ==================== PAYMENT ====================
print_step("Getting Session ID...")
# Must include delivered orders to find it
res = session_employee.get(
    f"{API_EMPLOYEE}/api/orders?limit=100&include_delivered=true", timeout=10
)
orders = res.json().get("orders", [])
target_order = next((o for o in orders if o["id"] == order_id), None)
if not target_order:
    print("Order not found in list. Available IDs:", [o["id"] for o in orders])
    sys.exit(1)
session_id = target_order["session_id"]
print(f"Session ID: {session_id}")

print_step("Processing Payment...")
res = session_employee.post(
    f"{API_EMPLOYEE}/api/sessions/{session_id}/pay",
    json={"payment_method": "cash", "tip_amount": 10.0},
    timeout=10,
)
check(res, 200)
print("Payment Successful")

# ==================== CLEANUP PRODUCT ====================
print_step("Deleting Product...")
try:
    res = session_employee.delete(f"{API_EMPLOYEE}/api/menu-items/{product_id}", timeout=10)
    if res.status_code == 409:
        print("Verified: Cannot delete product with orders (Constraint correct).")
    else:
        check(res, 200)
        print("Product Deleted")
except Exception as e:
    print("Delete check failed", e)

# ==================== ROLES MANAGEMENT ====================
print_step("Testing Roles Management...")
role_name = f"qa_role_{int(time.time())}"
new_role = {
    "name": role_name,
    "display_name": "QA Role Automated",
    "description": "Created by QA Script",
    "permissions": ["waiter-board"],
}
print(f"Creating Role {role_name}...")
res = session_employee.post(f"{API_EMPLOYEE}/api/roles", json=new_role, timeout=10)
check(res, 201)
role_id = res.json().get("id")
print(f"Created Role ID: {role_id}")

print("Updating Role Permissions...")
update_payload = {"permissions": ["waiter-board", "kitchen-board"]}
res = session_employee.put(f"{API_EMPLOYEE}/api/roles/{role_id}", json=update_payload, timeout=10)
check(res, 200)

print("Deleting Role...")
res = session_employee.delete(f"{API_EMPLOYEE}/api/roles/{role_id}", timeout=10)
check(res, 200)
print("Role Deleted")

# ==================== SETTINGS MANAGEMENT ====================
print_step("Testing Settings Management...")
setting_key = "store_cancel_reason"
print(f"Reading {setting_key}...")
res = session_employee.get(f"{API_EMPLOYEE}/api/settings/{setting_key}", timeout=10)
check(res, 200)
original_val = res.json().get("data", {}).get("value")
print(f"Original Value: {original_val}")

print(f"Updating {setting_key} to 'false'...")
res = session_employee.put(
    f"{API_EMPLOYEE}/api/settings/{setting_key}", json={"value": "false"}, timeout=10
)
check(res, 200)

print("Verifying Update...")
res = session_employee.get(f"{API_EMPLOYEE}/api/settings/{setting_key}", timeout=10)
new_val = res.json().get("data", {}).get("value")
if str(new_val).lower() != "false":
    print(f"FAILED: Expected false, got {new_val}")
    sys.exit(1)

print("Restoring Value...")
# Restore to string "true" if it was "true"
restore_val = "true" if str(original_val).lower() == "true" else original_val
res = session_employee.put(
    f"{API_EMPLOYEE}/api/settings/{setting_key}", json={"value": restore_val}, timeout=10
)
check(res, 200)
print("Settings Restored")

print("\n[SUCCESS] All QA Modules Verified Successfully.")
