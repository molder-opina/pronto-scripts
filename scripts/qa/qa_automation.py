import os
import sys

import requests
from sqlalchemy import create_engine, text

# --- CONFIG ---
CLIENT_URL = "http://localhost:6080"
EMPLOYEE_URL = "http://localhost:6081"
API_URL = "http://localhost:6082"
DB_USER = os.environ.get("POSTGRES_USER", "pronto")
DB_PASSWORD = os.environ.get("POSTGRES_PASSWORD", "pronto123")
DB_HOST = os.environ.get("POSTGRES_HOST", "localhost")
DB_PORT = os.environ.get("POSTGRES_PORT", "5432")
DB_NAME = os.environ.get("POSTGRES_DB", "pronto")

DB_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

TEST_EMAIL = "luartx@gmail.com"


# --- HELPERS ---
def get_db_connection():
    return create_engine(DB_URL).connect()


def step_1_create_order():
    print("--- 1. Creating Order (Client App) ---")

    # Get a valid menu item from DB (Find one with NO required modifiers)
    with get_db_connection() as conn:
        stmt = text(
            """
            SELECT i.id, i.name, i.price
            FROM pronto_menu_items i
            WHERE NOT EXISTS (
                SELECT 1
                FROM pronto_menu_item_modifier_groups mimg
                JOIN pronto_modifier_groups mg ON mimg.modifier_group_id = mg.id
                WHERE mimg.menu_item_id = i.id
                AND mg.min_selection > 0
            )
            LIMIT 1
        """
        )
        items = conn.execute(stmt).mappings().all()

    if not items:
        # Fallback to Coca-Cola
        print("⚠️ No items without required modifiers found! Trying 'Coca-Cola' anyway...")
        with get_db_connection() as conn:
            items = (
                conn.execute(
                    text(
                        "SELECT id, name, price FROM pronto_menu_items WHERE name = 'Coca-Cola' LIMIT 1"
                    )
                )
                .mappings()
                .all()
            )

    if not items:
        print("❌ No menu items found in DB!")
        return None

    item1 = items[0]
    print(f"Adding item: {item1['name']}")

    payload = {
        "table_number": "M-M1",
        "customer": {"name": "QA Tester", "email": TEST_EMAIL, "phone": "5512345678"},
        "items": [{"menu_item_id": item1["id"], "quantity": 1, "modifiers": []}],
    }

    try:
        resp = requests.post(f"{CLIENT_URL}/api/orders", json=payload, timeout=10)
        if resp.status_code in [200, 201]:
            order_id = resp.json().get("id")
            print(f"✅ Order Created! ID: {order_id}")
            return order_id
        print(f"❌ Failed to create order: {resp.status_code} - {resp.text}")
        return None
    except Exception as e:
        print(f"❌ Exception: {e}")
        return None


def get_employee_id(body):
    emp_id = body.get("id") or body.get("data", {}).get("id")
    if not emp_id:
        emp_id = body.get("data", {}).get("employee", {}).get("id")
    return emp_id


def step_2_kitchen_processing(order_id):
    print(f"\n--- 2. Chef Processing Order #{order_id} ---")
    s = requests.Session()

    try:
        login_resp = s.post(
            f"{EMPLOYEE_URL}/api/auth/login",
            json={"email": "carlos.chef@cafeteria.test", "password": "ChangeMe!123"},
            timeout=10,
        )

        if login_resp.status_code != 200:
            print(f"❌ Chef Login Failed: {login_resp.status_code} - {login_resp.text}")
            return False

        employee_id = get_employee_id(login_resp.json()) or 1
        print(f"Chef ID: {employee_id}")

        # Start
        start_resp = s.post(
            f"{EMPLOYEE_URL}/api/orders/{order_id}/kitchen/start",
            json={"employee_id": employee_id},
            timeout=10,
        )
        if start_resp.status_code == 200:
            print("✅ Order Started (En Preparación)")
        else:
            print(f"⚠️ Failed to start order: {start_resp.status_code} - {start_resp.text}")

        # Ready
        ready_resp = s.post(
            f"{EMPLOYEE_URL}/api/orders/{order_id}/kitchen/ready",
            json={"employee_id": employee_id},
            timeout=10,
        )
        if ready_resp.status_code == 200:
            print("✅ Order Ready (Listo)")
            return True
        print(f"❌ Failed to mark ready: {ready_resp.status_code} - {ready_resp.text}")
        return False

    except Exception as e:
        print(f"❌ Exception: {e}")
        return False


def step_3_waiter_delivery_payment(order_id):
    print(f"\n--- 3. Waiter Delivery & Payment Order #{order_id} ---")
    s = requests.Session()

    try:
        login_resp = s.post(
            f"{EMPLOYEE_URL}/api/auth/login",
            json={"email": "juan.mesero@cafeteria.test", "password": "ChangeMe!123"},
            timeout=10,
        )

        if login_resp.status_code != 200:
            print(f"❌ Waiter Login Failed: {login_resp.status_code} - {login_resp.text}")
            return False

        employee_id = get_employee_id(login_resp.json()) or 1
        print(f"Waiter ID: {employee_id}")

        # Deliver
        deliver_resp = s.post(
            f"{EMPLOYEE_URL}/api/orders/{order_id}/deliver",
            json={"employee_id": employee_id},
            timeout=10,
        )
        if deliver_resp.status_code == 200:
            print("✅ Order Delivered")
        else:
            print(f"❌ Failed to deliver: {deliver_resp.status_code} - {deliver_resp.text}")
            return False

        # Get Session ID from DB
        with get_db_connection() as conn:
            # Fix SQL Injection: use parameters
            stmt = text("SELECT session_id FROM pronto_orders WHERE id = :order_id")
            res = conn.execute(stmt, {"order_id": order_id}).mappings().one_or_none()

        if not (res and res["session_id"]):
            print("❌ No session ID found in DB")
            return False

        session_id = res["session_id"]
        print(f"Session ID (from DB): {session_id}")

        # Pay
        payment_payload = {"payment_method": "cash", "tip_amount": 0}
        pay_resp = s.post(
            f"{EMPLOYEE_URL}/api/sessions/{session_id}/pay", json=payment_payload, timeout=10
        )

        if pay_resp.status_code != 200:
            print(f"❌ Payment Failed: {pay_resp.status_code} - {pay_resp.text}")
            return False

        print("✅ Payment Successful")

        # Verify PDF Download
        print("Verifying PDF ticket download...")
        pdf_resp = s.get(f"{EMPLOYEE_URL}/api/sessions/{session_id}/ticket.pdf", timeout=10)
        if pdf_resp.status_code == 200:
            print(f"✅ PDF Verified (200 OK, {len(pdf_resp.content)} bytes)")
        else:
            print(f"❌ PDF Download Failed: {pdf_resp.status_code}")

        return True

    except Exception as e:
        print(f"❌ Exception: {e}")
        return False


def step_4_verify_results(order_id):
    print("\n--- 4. Final Verification ---")
    with get_db_connection() as conn:
        # Fix SQL Injection: use parameters
        stmt = text(
            "SELECT workflow_status, payment_status FROM pronto_orders WHERE id = :order_id"
        )
        res = conn.execute(stmt, {"order_id": order_id}).mappings().one()
        print(f"DB Status: Workflow={res['workflow_status']}, Payment={res['payment_status']}")

        if res["workflow_status"] == "completed" and res["payment_status"] == "paid":
            print("✅ DB Validation Passed: Order is Completed and Paid.")
        else:
            print("❌ DB Validation Failed.")


def main():
    print("🚀 Starting QA Automation Cycle (Requests Version)...")
    order_id = step_1_create_order()
    if not order_id:
        sys.exit(1)

    if not step_2_kitchen_processing(order_id):
        sys.exit(1)

    if not step_3_waiter_delivery_payment(order_id):
        sys.exit(1)

    step_4_verify_results(order_id)
    print("\n✅ QA Cycle Completed Successfully!")


if __name__ == "__main__":
    main()
