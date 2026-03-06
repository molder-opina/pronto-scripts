
import sys
import os
import uuid
from decimal import Decimal

# Add path to include pronto-libs
sys.path.append(os.path.join(os.path.dirname(__file__), "../../../pronto-libs/src"))

from pronto_shared.config import load_config
from pronto_shared.db import init_engine, get_session
from pronto_shared.models import DiningSession, Order, OrderItem, Customer, MenuItem, Payment
from pronto_shared.services.order_service import finalize_payment
from pronto_shared.services.customer_service import create_customer
from pronto_shared.constants import OrderStatus, SessionStatus
from http import HTTPStatus

def run_test():
    print("Starting Split Bill Verification (Direct Service)...")
    
    # Load config (assuming we are in dev/employees env)
    config = load_config("employees")
    init_engine(config)
    
    unique_id = str(uuid.uuid4())[:8]
    session_id = None
    
    try:
        with get_session() as db:
            # 1. Setup Data
            print("Creating test customer and session...")
            cust_data = create_customer(
                db, 
                f"Test{unique_id}", 
                f"split_{unique_id}@test.com", 
                "password",
                phone="5555555555"
            )
            customer_id = uuid.UUID(cust_data["id"])
            
            # Create Session
            dining_session = DiningSession(
                id=uuid.uuid4(),
                customer_id=customer_id,
                table_number=f"T-{unique_id}",
                status=SessionStatus.OPEN.value,
                total_amount=200.00
            ) 
            # Note: total_amount is usually calculated from orders, but we can force it for testing if we don't add orders
            # But recompute_totals in finalize_payment will overwrite it!
            # So we MUST add an order.
            
            db.add(dining_session)
            session_id = dining_session.id
            
            # Create Order with Item
            order = Order(
                id=uuid.uuid4(),
                session_id=session_id,
                customer_id=customer_id,
                workflow_status=OrderStatus.DELIVERED.value,
                subtotal=200.00,
                tax_amount=0.00,
                total_amount=200.00
            )
            db.add(order)
            
            # Commit to save initial state
            db.commit()
            print(f"Created Session {session_id} with Total: 200.00")
            
        # 2. Partial Payment (100.00)
        print("Processing partial payment of 100.00...")
        # finalize_payment handles transaction internally
        
        # We assume finalize_payment takes uuid or int? 
        # Models use UUID, but type hint says int in some places. 
        # Code uses `DiningSession.id == session_id` so UUID object should work.
        
        result, status = finalize_payment(
            session_id=session_id,
            payment_method="cash",
            payment_amount=100.00
        )
        
        if status != 200:
            print(f"Partial payment failed: {status} {result}")
            return False
            
        print("Partial payment success. Verifying state...")
        
        with get_session() as db:
            ds = db.get(DiningSession, session_id)
            print(f"Session Status: {ds.status}")
            print(f"Total Paid: {ds.total_paid}")
            
            if ds.status == SessionStatus.PAID.value:
                print("Error: Session marked PAID prematurely.")
                return False
                
            if float(ds.total_paid) != 100.00:
                 print(f"Error: total_paid mismatch (Expected 100.0, Got {ds.total_paid})")
                 return False
                 
            # Check Payment Record
            payment = db.query(Payment).filter_by(session_id=session_id).first()
            if not payment:
                print("Error: No payment record found.")
                return False
            if float(payment.amount) != 100.00:
                print(f"Error: Payment record amount mismatch ({payment.amount})")
                return False
                
        # 3. Pay Remaining (100.00)
        print("Processing remaining payment of 100.00...")
        
        result, status = finalize_payment(
            session_id=session_id,
            payment_method="card",
            payment_amount=100.00
        )
        
        if status != 200:
            print(f"Remaining payment failed: {status} {result}")
            return False
            
        with get_session() as db:
            ds = db.get(DiningSession, session_id)
            print(f"Session Status: {ds.status}")
            print(f"Total Paid: {ds.total_paid}")
            
            if ds.status != SessionStatus.PAID.value:
                print(f"Error: Session NOT marked PAID. Status: {ds.status}")
                return False
            
            if float(ds.total_paid) != 200.00:
                 print(f"Error: total_paid mismatch (Expected 200.0, Got {ds.total_paid})")
                 return False
                 
            # Check Payments
            payments = db.query(Payment).filter_by(session_id=session_id).all()
            if len(payments) != 2:
                print(f"Error: Expected 2 payment records, got {len(payments)}")
                return False
                
        print("✅ Split Bill Verification Passed")
        return True

    except Exception as e:
        print(f"Test failed with exception: {e}")
        import traceback
        traceback.print_exc()
        return False
    finally:
        # Cleanup (optional but good)
        pass

if __name__ == "__main__":
    if run_test():
        sys.exit(0)
    else:
        sys.exit(1)
