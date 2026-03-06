#!/usr/bin/env python3
"""
Verify Split Bill API functionality.
"""

import sys
import json
import requests
import time
import os

# Configuration
API_URL = "http://localhost:6082/api"
ADMIN_EMAIL = "admin@cafeteria.test"
# Try passwords
PASSWORDS = ["ChangeMe!123", "pronto_password", "Test123!", "admin"]
PRONTO_INTERNAL_SECRET = os.getenv("PRONTO_INTERNAL_SECRET", "")

if not PRONTO_INTERNAL_SECRET:
    print("Error: PRONTO_INTERNAL_SECRET is required")
    sys.exit(1)


def login():
    """Login as admin and return session."""
    session = requests.Session()
    session.headers.update({"X-Pronto-Internal-Auth": PRONTO_INTERNAL_SECRET})

    # Try URLs
    urls = [f"{API_URL}/employees/auth/login", f"{API_URL}/auth/login"]

    for url in urls:
        for pwd in PASSWORDS:
            try:
                # Get CSRF token first? Usually provided in cookie on first GET?
                # Or just try POST.
                # If CSRF is missing in cookie, we might need a GET /health or /api/constants?
                session.get(f"{API_URL.replace('/api', '')}/health")  # Prime cookies?

                payload = {"email": ADMIN_EMAIL, "password": pwd}
                print(f"Trying login at {url} with {pwd}...")
                resp = session.post(url, json=payload)

                if resp.status_code == 200:
                    data = resp.json()["data"]
                    token = data["access_token"]
                    print("Login successful")

                    # CSRF
                    csrf_token = None
                    for cookie in session.cookies:
                        if "csrf" in cookie.name:
                            csrf_token = cookie.value

                    if not csrf_token:
                        # Maybe in headers or data?
                        csrf_token = resp.headers.get("X-CSRF-TOKEN")

                    if not csrf_token:
                        # Check cookies dict
                        c = session.cookies.get_dict()
                        csrf_token = c.get("csrf_access_token")

                    # Setup session headers
                    session.headers.update(
                        {
                            "Authorization": f"Bearer {token}",
                            "X-CSRF-TOKEN": csrf_token if csrf_token else "",
                        }
                    )

                    return session, token

            except requests.exceptions.ConnectionError:
                print(f"Error: Cannot connect to {API_URL}")
                sys.exit(1)

    print("Login failed")
    sys.exit(1)


def create_active_session(session):
    """Create a session via Order."""
    url = f"{API_URL}/orders"

    # Get Menu Item
    menu_resp = session.get(f"{API_URL}/menu")
    if menu_resp.status_code != 200:
        print("Failed to get menu")
        sys.exit(1)

    menu_data = menu_resp.json()["data"]
    categories = menu_data.get("categories", [])
    if not categories:
        print("No menu categories")
        sys.exit(1)

    # Find a valid item
    item_id = None
    for cat in categories:
        if cat["items"]:
            item_id = cat["items"][0]["id"]
            break

    if not item_id:
        print("No items found")
        sys.exit(1)

    payload = {
        "items": [{"menu_item_id": item_id, "quantity": 1, "modifiers": []}],
        "table_id": "99",
        "notes": "Test Split Bill",
    }

    resp = session.post(url, json=payload)
    if resp.status_code != 201:
        print(f"Failed to create order: {resp.status_code} {resp.text}")
        sys.exit(1)

    order_data = resp.json()
    # Ensure structure
    data = order_data.get("data", order_data)

    session_id = data.get("session_id") or data.get("order", {}).get("session_id")
    print(f"Created session {session_id}")
    return session_id


def verify_split_flow(session, session_id):
    # 1. Create Split
    print("Creating split...")
    url = f"{API_URL}/split-bills/sessions/{session_id}/create"
    payload = {"split_type": "equal", "number_of_people": 2}
    resp = session.post(url, json=payload)

    if resp.status_code != 201:
        print(f"Failed to create split: {resp.status_code} {resp.text}")
        sys.exit(1)

    split_data = resp.json()["data"]
    people = split_data["people"]
    print(f"Split created with {len(people)} people")

    # 2. Pay Person 1
    p1 = people[0]
    print(f"Paying for {p1['name']}...")
    url = f"{API_URL}/split-bills/people/{p1['id']}/pay"
    resp = session.post(url, json={"payment_method": "cash"})

    if resp.status_code != 200:
        print(f"Failed to pay p1: {resp.status_code} {resp.text}")
        sys.exit(1)

    data = resp.json()["data"]
    if data["split_completed"]:
        print("Error: Split should not be completed yet")
        sys.exit(1)

    # 3. Pay Person 2
    p2 = people[1]
    print(f"Paying for {p2['name']}...")
    url = f"{API_URL}/split-bills/people/{p2['id']}/pay"
    resp = session.post(url, json={"payment_method": "cash"})

    if resp.status_code != 200:
        print(f"Failed to pay p2: {resp.status_code} {resp.text}")
        sys.exit(1)

    data = resp.json()["data"]
    if not data["split_completed"]:
        print("Error: Split should be completed")
        sys.exit(1)

    # 4. Verify Session Closed
    print("Verifying session status...")
    url = f"{API_URL}/sessions/{session_id}"
    resp = session.get(url)
    session_data = resp.json()["data"]

    if session_data["status"] != "paid":
        print(f"Error: Session status is {session_data['status']}, expected 'paid'")
        sys.exit(1)

    print("SUCCESS: Split bill flow verified!")


if __name__ == "__main__":
    try:
        session, token = login()
        session_id = create_active_session(session)
        verify_split_flow(session, session_id)
    except Exception as e:
        print(f"Test failed: {e}")
        # traceback
        import traceback

        traceback.print_exc()
        sys.exit(1)
