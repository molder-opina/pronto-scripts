
import sys
import os
import uuid
import time
from datetime import datetime

# Add paths
sys.path.append(os.path.join(os.path.dirname(__file__), "../../../pronto-libs/src"))

from pronto_shared.config import load_config
from pronto_shared.db import init_engine, get_session
from pronto_shared.models import DiningSession, Customer, Feedback, Employee
from pronto_shared.services.feedback_service import FeedbackService
from pronto_shared.constants import SessionStatus, Roles

def run_test():
    print("Starting Feedback API Verification (Service Layer)...")
    
    config = load_config("employees")
    init_engine(config)
    
    unique_id = str(uuid.uuid4())[:8]
    
    try:
        with get_session() as db:
            # 1. Setup Data
            print("Creating test data...")
            # Customer
            customer = Customer(
                id=uuid.uuid4(),
                name=f"FeedbackUser {unique_id}",
                email=f"feedback_{unique_id}@test.com",
                phone="5555555555"
            )
            db.add(customer)
            
            # Employee (Waiter)
            waiter = Employee(
                id=uuid.uuid4(),
                employee_code=f"W-{unique_id}",
                first_name="Waiter",
                last_name=unique_id,
                email=f"waiter_{unique_id}@pronto.com",
                role=Roles.WAITER.value,
                is_active=True
            )
            # Set password to generate auth_hash etc
            waiter.set_password("password")
            db.add(waiter)
            
            # Session
            session = DiningSession(
                id=uuid.uuid4(),
                customer_id=customer.id,
                table_number=f"T-F{unique_id}",
                status=SessionStatus.PAID.value,
                total_amount=100.00,
                opened_at=datetime.now()
            )
            db.add(session)
            
            db.commit()
            
            session_id = session.id
            employee_id = waiter.id
            customer_id = customer.id
            
            print(f"Created Session {session_id}, Customer {customer_id}, Employee {employee_id}")
            
        # 2. Submit Feedback via Service
        print("Submitting feedback...")
        
        feedback_data = {
            "session_id": session_id,
            "employee_id": employee_id,
            "category": "service",
            "rating": 5,
            "comment": "Excellent service by the waiter!",
            "is_anonymous": False,
            "customer_id": customer_id 
        }
        
        # Note: FeedbackService.create_feedback expects dict matching model fields?
        # let's checks signature again. 
        # Yes, creates Feedback(**data).
        
        response, status = FeedbackService.create_feedback(feedback_data)
        
        if status != 201:
            print(f"Feedback creation failed: {status} {response}")
            return False
            
        print(f"Response: {response}")
        feedback_id = response.get("data", {}).get("id")
        print(f"Feedback created: {feedback_id}")
        
        # 3. Verify Storage
        with get_session() as db:
            fb = db.get(Feedback, feedback_id)
            if not fb:
                print("Error: Feedback not found in DB.")
                return False
                
            if fb.rating != 5 or fb.comment != "Excellent service by the waiter!":
                print(f"Error: Data mismatch. Rating={fb.rating}, Comment={fb.comment}")
                return False
                
            print("✅ Feedback stored correctly.")
            
        # 4. Verify Retrieval by Session
        response, status = FeedbackService.get_feedback_by_session(session_id)
        if status != 200:
             print(f"Get by session failed: {status}")
             return False
             
        print(f"Retrieval Response: {response}")
        feedbacks = response.get("data", {}).get("feedbacks", [])
        if len(feedbacks) != 1:
            print(f"Error: Expected 1 feedback, got {len(feedbacks)}")
            return False
            
        print("✅ Feedback retrieval verified.")
        
        return True

    except Exception as e:
        print(f"Test failed with exception: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    if run_test():
        sys.exit(0)
    else:
        sys.exit(1)
