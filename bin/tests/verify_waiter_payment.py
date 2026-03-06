import sys
import os
import time
from sqlalchemy import select, update
from decimal import Decimal

# Add path to include pronto_shared
sys.path.append(os.path.join(os.path.dirname(__file__), "../../../pronto-libs/src"))
sys.path.append(os.path.join(os.path.dirname(__file__), "../../../pronto-employees/src"))

from pronto_shared.config import load_config
from pronto_shared.db import init_engine, get_session
from pronto_shared.models import SystemSetting, DiningSession, Order, Employee
# We need to simulate the service call with correct context
# Since can_collect_payment uses cached DB lookup, we need to invalidate cache or rely on it
from pronto_shared.services.business_config_service import invalidate_config_cache
from pronto_shared.services.order_service import prepare_checkout, finalize_payment
from pronto_shared.constants import OrderStatus

# Mocking get_current_user context
from contextlib import contextmanager
from unittest.mock import patch

@contextmanager
def mock_waiter_context():
    with patch("pronto_shared.jwt_middleware.get_current_user") as mock_user, \
         patch("pronto_shared.services.order_service.can_collect_payment") as mock_check:
         
        # We assume the service calls `can_collect_payment` internally or via decorator
        # Actually `session_pay` endpoint calls `can_collect_payment`.
        # BUT we are calling the SERVICE function `finalize_payment` directly?
        # Wait, the permission check is in the ROUTE handler `pronto-api/src/api_app/routes/employees/sessions.py`.
        # The SERVICE layer `finalize_payment` typically doesn't check permissions, the API layer does.
        # So testing the service directly won't Verify the API permission logic!
        
        # We need to test the API endpoint or simulate the route logic.
        # Since we can't easily spin up the API for this script, we will import the ROUTE function
        # provided we can mock the request/current_user.
        
        yield

def update_setting(session, allowed: bool):
    stmt = select(SystemSetting).where(SystemSetting.config_key == 'waiter_can_collect')
    setting = session.execute(stmt).scalars().first()
    if setting:
        setting.config_value = str(allowed).lower()
        session.commit()
    else:
        print("Setting 'waiter_can_collect' not found!")
    
    invalidate_config_cache()
    # Also invalidate lru_cache of route if possible, or just wait?
    # The route calls `can_collect_payment_cached` which has lru_cache. 
    # We can't easily clear that from here unless we import the route module.

def run_verification():
    # Load env
    config = load_config("employees")
    init_engine(config)
    
    # We need to import the route logic to test permission
    # Adjusted import path
    sys.path.append(os.path.join(os.path.dirname(__file__), "../../../pronto-api/src"))
    from api_app.routes.employees.sessions import session_pay, _can_collect_payment_cached
    from werkzeug.test import EnvironBuilder
    from flask import Request
    
    with get_session() as session:
        # Create a dummy session with explicit ID to avoid auto-increment issues
        import uuid
        sid = uuid.uuid4()
        ds = DiningSession(id=sid, table_number="T-Verify", status="open", total_amount=100.00)
        session.add(ds)
        session.commit()
        session_id = ds.id
        print(f"Created testing session {session_id}")
        
    # Create a minimal Flask app to provide context
    from flask import Flask
    app = Flask(__name__)
    
    # Helper to mock request
    def run_check(as_allowed: bool) -> int:
        # Update DB
        with get_session() as s:
            update_setting(s, as_allowed)
        
        # Clear cache
        _can_collect_payment_cached.cache_clear()
        
        with app.test_request_context(json={"payment_method": "cash"}):
             # Mock request context
             # scope_required decorator checks "active_scope"
             user_payload = {"scope": "waiter", "role": "waiter", "active_scope": "waiter", "employee_role": "waiter"}
             with patch("pronto_shared.jwt_middleware.get_current_user", return_value=user_payload), \
                  patch("pronto_shared.services.order_service.finalize_payment", return_value=({}, 200)):
                
                # Call the route function directly
                print(f"Testing with waiter_can_collect = {as_allowed}...")
                response, status = session_pay(session_id)
                return status

    try:
        # Test 1: Disable payment -> Expect 403
        status_code = run_check(False)
        if status_code == 403:
             print("SUCCESS: Waiter blocked (403) when setting is False.")
        else:
             print(f"FAILURE: Expected 403, got {status_code}")
             
        # Test 2: Enable payment -> Expect 200
        status_code = run_check(True)
        if status_code == 200:
             print("SUCCESS: Waiter allowed (200) when setting is True.")
        else:
             print(f"FAILURE: Expected 200, got {status_code}")

    finally:
        # Cleanup
        with get_session() as s:
             # We need to use delete because we created it with specific ID
             s.execute(update(DiningSession).where(DiningSession.id == session_id).values(status="closed"))
             s.commit()
            
if __name__ == "__main__":
    run_verification()
