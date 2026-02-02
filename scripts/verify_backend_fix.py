import json
import os
import sys
from datetime import datetime

# Add app context
sys.path.append("/opt/pronto")

from flask import Flask

from pronto_employees.app import create_app
from shared.db import get_session, init_engine
from shared.models import Customer, DiningSession, MenuItem, Order, OrderItem, OrderStatus
from shared.services.order_service import list_orders


def verify_backend():
    print("Initializing app context...")
    app = create_app()

    with app.app_context():
        print("--- Verifying list_orders ---")
        try:
            result = list_orders(limit=5)
            print(f"list_orders successful. Retrieved {len(result['orders'])} orders.")
            for o in result["orders"]:
                print(f" - Order {o['id']}: {o['workflow_status']}")
        except Exception as e:
            print(f"CRITICAL: list_orders failed: {e}")
            import traceback

            traceback.print_exc()
            return False

        print("\n--- Verifying Order Creation (Simulation) ---")
        try:
            with get_session() as db:
                # Get a customer
                customer = db.query(Customer).first()
                if not customer:
                    print("No customer found, creating dummy...")
                    customer = Customer(
                        name="Test",
                        email="test@test.com",
                        email_hash="hash",
                        name_encrypted="enc",
                        email_encrypted="enc",
                    )
                    db.add(customer)
                    db.flush()

                # Create Session
                order_session = DiningSession(
                    customer_id=customer.id, table_number="DEBUG-TEST", status="open"
                )
                db.add(order_session)
                db.flush()

                # Get items
                menu_item = db.query(MenuItem).first()
                if not menu_item:
                    print("No menu items found! Cannot test order creation.")
                    return False

                print(f"Creating order with item: {menu_item.name}")

                # This was the problematic part: passing items=[] to constructor vs adding them later
                # We replicate the FIX here: NOT passing items kwarg
                order = Order(
                    session_id=order_session.id,
                    customer_id=customer.id,
                    total_amount=100.0,
                    workflow_status=OrderStatus.NEW.value,
                    created_at=datetime.utcnow(),
                    # items=[...]  <-- This caused the error if passed as list of dicts
                )
                db.add(order)
                db.flush()

                # Add item manually
                order_item = OrderItem(
                    order_id=order.id,
                    menu_item_id=menu_item.id,
                    quantity=1,
                    unit_price=menu_item.price,
                    name=menu_item.name,
                )
                db.add(order_item)
                db.commit()

                print(f"SUCCESS: Created Order ID {order.id}")
                return True

        except Exception as e:
            print(f"CRITICAL: Order creation failed: {e}")
            import traceback

            traceback.print_exc()
            return False


if __name__ == "__main__":
    success = verify_backend()
    sys.exit(0 if success else 1)
