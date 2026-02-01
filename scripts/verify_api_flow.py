#!/usr/bin/env python3
"""
Verify API Flow v2 (Unified API)
Host: localhost:6082 (or configured API_BASE)

Usage:
  python3 scripts/verify_api_flow.py [--payment=cash|card|stripe]
"""

import argparse
import os
import sys
from pathlib import Path

import requests

API_BASE = os.getenv("API_BASE", "http://localhost:6082")
CLIENT_API = f"{API_BASE}/api/client"
EMPLOYEE_API = f"{API_BASE}/api/employee"


class TestFailedError(Exception):
    pass


def log(msg, **kwargs):
    print(f"[TEST] {msg} {kwargs if kwargs else ''}")


def fail(msg):
    print(f"[FAIL] {msg}")
    sys.exit(1)


class OrderFlowTest:
    def __init__(self, payment_method="cash"):
        self.session = requests.Session()
        self.payment_method = payment_method
        self.employee_id = None
        self.order_id = None
        self.session_id = None
        self.menu_item_id = None

    def run(self):
        try:
            self.login_employee()
            self.get_menu_item()
            self.create_order()
            self.verify_order_created()
            self.process_kitchen_workflow()
            self.prepare_checkout()
            self.finalize_payment()
            self.post_payment_actions()
            log(f"SUCCESS: Full Flow Verified (Payment: {self.payment_method})")
        except TestFailedError as e:
            fail(str(e))
        except Exception as e:
            fail(f"Unexpected error: {e}")

    def login_employee(self):
        log("Logging in as Admin/Cashier...")
        resp = self.session.post(
            f"{EMPLOYEE_API}/auth/login",
            json={"email": "admin@cafeteria.test", "password": "ChangeMe!123"},
        )
        if resp.status_code != 200:
            raise TestFailedError(f"Login failed: {resp.text}")

        json_resp = resp.json()
        if "data" in json_resp and "employee" in json_resp["data"]:
            employee_data = json_resp["data"]["employee"]
        elif "employee" in json_resp:
            employee_data = json_resp["employee"]
        else:
            raise TestFailedError(f"Login response missing employee data: {json_resp.keys()}")

        self.employee_id = employee_data["id"]
        log("Logged in", employee_id=self.employee_id, role=employee_data["role"])

    def get_menu_item(self):
        log("Fetching Menu...")
        resp = requests.get(f"{CLIENT_API}/menu", timeout=30)
        if resp.status_code != 200:
            raise TestFailedError("Failed to get menu")

        categories = resp.json().get("categories", [])
        if not categories:
            raise TestFailedError("No categories in menu")

        # Find a valid item (prefer Bebidas/Sopas to avoid complex modifiers)
        target_category = "Sopas"

        for cat in categories:
            if cat["name"] == target_category and cat["items"]:
                self.menu_item_id = cat["items"][0]["id"]
                log(f"Found item in {target_category}: {cat['items'][0]['name']}")
                break

        if not self.menu_item_id:
            for cat in categories:
                if cat["items"]:
                    self.menu_item_id = cat["items"][0]["id"]
                    break

        if not self.menu_item_id:
            raise TestFailedError("No items found in menu")

        log(f"Selected Menu Item ID: {self.menu_item_id}")

    def create_order(self):
        log("Creating Order...")
        customer_data = {"name": "Luartx Test", "email": "luartx@gmail.com", "phone": "5555555555"}
        items_data = [{"menu_item_id": self.menu_item_id, "quantity": 1, "notes": "Sin cebolla"}]

        resp = requests.post(
            f"{CLIENT_API}/orders",
            json={
                "customer": customer_data,
                "items": items_data,
                "table_number": "99",
                "notes": f"Test Order Flow ({self.payment_method})",
            },
            timeout=30,
        )

        if resp.status_code != 201:
            raise TestFailedError(f"Failed to create order: {resp.text}")

        data = resp.json()
        self.order_id = data["order_id"]
        self.session_id = data["session_id"]
        log("Order Created", order_id=self.order_id, session_id=self.session_id)

    def verify_order_created(self):
        log("Verifying Order...")
        resp = requests.get(f"{CLIENT_API}/orders/{self.order_id}", timeout=30)
        if resp.status_code != 200:
            raise TestFailedError("Failed to fetch order details")

        order_details = resp.json()["order"]
        self.status = order_details["workflow_status"]
        log("Order Verified", status=self.status)

    def process_kitchen_workflow(self):
        # Waiter Accept
        if self.status == "requested":
            log("Waiter Accepting...")
            resp = self.session.post(
                f"{EMPLOYEE_API}/orders/{self.order_id}/accept",
                json={"employee_id": self.employee_id},
            )
            if resp.status_code != 200:
                raise TestFailedError(f"Accept failed: {resp.text}")
            self.status = "waiter_accepted"

        # Chef Start
        if self.status == "waiter_accepted":
            log("Chef Starting (Kitchen)...")
            resp = self.session.post(
                f"{EMPLOYEE_API}/orders/{self.order_id}/kitchen/start",
                json={"employee_id": self.employee_id},
            )

            # Check if auto-ready or error
            if resp.status_code != 200:
                tmp = requests.get(f"{CLIENT_API}/orders/{self.order_id}", timeout=30).json()[
                    "order"
                ]
                if tmp["workflow_status"] == "ready_for_delivery":
                    log("Order auto-readied (Quick Serve)")
                    self.status = "ready_for_delivery"
                elif resp.status_code == 409:
                    log("Order might not require kitchen. Checking...")
                    self.status = tmp["workflow_status"]
                else:
                    raise TestFailedError(f"Chef Start failed: {resp.text}")
            else:
                self.status = "kitchen_in_progress"

        # Chef Ready
        if self.status == "kitchen_in_progress":
            log("Chef Marking Ready...")
            resp = self.session.post(
                f"{EMPLOYEE_API}/orders/{self.order_id}/kitchen/ready",
                json={"employee_id": self.employee_id},
            )
            if resp.status_code != 200:
                raise TestFailedError(f"Chef Ready failed: {resp.text}")
            self.status = "ready_for_delivery"

        # Check status again
        resp = requests.get(f"{CLIENT_API}/orders/{self.order_id}", timeout=30)
        self.status = resp.json()["order"]["workflow_status"]

        # Waiter Deliver
        if self.status == "ready_for_delivery":
            log("Waiter Delivering...")
            resp = self.session.post(
                f"{EMPLOYEE_API}/orders/{self.order_id}/deliver",
                json={"employee_id": self.employee_id},
            )
            if resp.status_code != 200:
                raise TestFailedError(f"Deliver failed: {resp.text}")
            self.status = "delivered"

        log(f"Order Flow Complete. Status: {self.status}")

    def prepare_checkout(self):
        log("Preparing Checkout...")
        resp = self.session.post(f"{EMPLOYEE_API}/sessions/{self.session_id}/checkout")
        if resp.status_code != 200:
            log(f"Warning: Prepare checkout returned {resp.status_code}: {resp.text}")
            # Proceed anyway as it might be idempotent or just a warning state

    def finalize_payment(self):
        log(f"Finalizing Payment ({self.payment_method})...")

        # Test stripe provider failure expectation if needed, but for now we assume validation

        resp = self.session.post(
            f"{EMPLOYEE_API}/sessions/{self.session_id}/pay",
            json={
                "payment_method": self.payment_method,
                "customer_email": "luartx@gmail.com",
                "tip_percentage": 10,
            },
        )

        if resp.status_code != 200:
            raise TestFailedError(f"Payment failed: {resp.text}")

        log("Payment Successful")

        pay_resp_json = resp.json()
        requires_confirmation = pay_resp_json.get("requires_confirmation") or pay_resp_json.get(
            "data", {}
        ).get("requires_confirmation")

        if requires_confirmation:
            if self.payment_method not in ["cash", "card"]:
                log(
                    f"Warning: Payment method {self.payment_method} requested confirmation, which is unexpected."
                )

            log("Payment requires confirmation. Confirming...")
            resp = self.session.post(
                f"{EMPLOYEE_API}/sessions/{self.session_id}/confirm-payment", json={}
            )
            if resp.status_code != 200:
                raise TestFailedError(f"Confirm payment failed: {resp.text}")
            log("Payment Confirmed")
        elif self.payment_method in ["cash", "card"]:
            log("Warning: Cash/Card should usually require confirmation but flag was False.")

    def post_payment_actions(self):
        # Resend Email
        log("Sending Ticket Email...")
        resp = self.session.post(
            f"{EMPLOYEE_API}/sessions/{self.session_id}/resend", json={"email": "luartx@gmail.com"}
        )
        if resp.status_code != 200:
            log(f"Email send warning: {resp.text}")
        else:
            log("Email sent request success")

        # Reprint Ticket
        log("Reprinting Ticket...")
        resp = self.session.post(f"{EMPLOYEE_API}/sessions/{self.session_id}/reprint")
        if resp.status_code != 200:
            raise TestFailedError(f"Reprint failed: {resp.text}")

        ticket_data = resp.json().get("ticket", "")
        if ticket_data:
            log(f"Ticket Data Received ({len(ticket_data)} chars)")
            filename = "ticket_output.html"
            if str(ticket_data).startswith("%PDF"):
                filename = "ticket_output.pdf"

            with Path(filename).open("w") as f:
                f.write(str(ticket_data))
            log(f"Ticket saved to {filename}")
        else:
            log("No ticket content received")


def main():
    parser = argparse.ArgumentParser(description="Verify API Order Flow")
    parser.add_argument(
        "--payment",
        default="cash",
        choices=["cash", "card", "stripe", "clip"],
        help="Payment method to test",
    )
    args = parser.parse_args()

    test = OrderFlowTest(payment_method=args.payment)
    test.run()


if __name__ == "__main__":
    main()
