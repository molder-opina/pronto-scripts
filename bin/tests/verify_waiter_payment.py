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
from pronto_shared.models import SystemSetting, DiningSession, Order, Employee, Table
from pronto_shared.services.business_config_service import invalidate_config_cache
from pronto_shared.services.payment_permission_service import (
    invalidate_payment_permissions_cache,
)

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

def _upsert_bool_setting(session, key: str, value: bool):
    stmt = select(SystemSetting).where(SystemSetting.config_key == key)
    setting = session.execute(stmt).scalars().first()
    if setting:
        setting.config_value = str(value).lower()
        setting.value_type = "bool"
    else:
        setting = SystemSetting(
            config_key=key,
            config_value=str(value).lower(),
            value_type="bool",
            category="payments",
            display_name=key,
        )
        session.add(setting)


def update_setting(session, waiter_allowed: bool):
    _upsert_bool_setting(session, "payments.enable_cashier_role", True)
    _upsert_bool_setting(
        session,
        "payments.allow_waiter_cashier_operations",
        waiter_allowed,
    )
    session.commit()
    invalidate_config_cache()
    invalidate_payment_permissions_cache()

def run_verification():
    # Load env
    config = load_config("employees")
    init_engine(config)
    
    # We need to import the route logic to test permission
    # Adjusted import path
    sys.path.append(os.path.join(os.path.dirname(__file__), "../../../pronto-api/src"))
    from api_app.routes.employees.sessions import session_pay
    from werkzeug.test import EnvironBuilder
    from flask import Request
    
    with get_session() as session:
        # Create a dummy session with explicit ID to avoid auto-increment issues
        import uuid
        sid = uuid.uuid4()
        table = session.execute(select(Table).where(Table.is_active.is_(True))).scalars().first()
        if not table:
            raise RuntimeError("No active table found for verification flow")
        ds = DiningSession(id=sid, table_id=table.id, status="open", total_amount=100.00)
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
        
        # Clear permission cache
        invalidate_payment_permissions_cache()
        
        with app.test_request_context(json={"payment_method": "cash"}):
             # Mock request context
             # scope_required decorator checks "active_scope"
             user_payload = {"scope": "waiter", "role": "waiter", "active_scope": "waiter", "employee_role": "waiter"}
             with patch("pronto_shared.jwt_middleware.get_current_user", return_value=user_payload), \
                  patch("pronto_shared.services.order_service.finalize_payment", return_value=({}, 200)):
                
                # Call the route function directly
                print(
                    "Testing with payments.allow_waiter_cashier_operations = "
                    f"{as_allowed}..."
                )
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
