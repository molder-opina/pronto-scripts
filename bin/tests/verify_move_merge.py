import sys
import os
import requests
import uuid
import time
from datetime import datetime
from dotenv import load_dotenv

# Add paths
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../pronto-libs/src")))

# Load .env BEFORE importing pronto_shared config/db which might rely on env vars
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../"))
load_dotenv(os.path.join(project_root, ".env"), override=True)

# Force localhost for DB connection since we are running outside Docker
os.environ["POSTGRES_HOST"] = "localhost"
if "DATABASE_URL" in os.environ:
    del os.environ["DATABASE_URL"]
print(f"DEBUG: POSTGRES_HOST in env: {os.environ.get('POSTGRES_HOST')}")

from pronto_shared.config import load_config
config = load_config("employees")
print(f"DEBUG: config.db_host: {config.db_host}")
from pronto_shared.db import init_engine, get_session
from pronto_shared.models import DiningSession, Customer, Employee, Table, Area
from pronto_shared.constants import SessionStatus, Roles
from pronto_shared.security import hash_identifier

# Configuration
API_BASE_URL = "http://localhost:6082/api"

def setup_test_data():
    """Create test data directly in DB."""
    config = load_config("employees")
    init_engine(config)
    
    unique_id = str(uuid.uuid4())[:8]
    data = {}
    
    from sqlalchemy import text
    
    with get_session() as db:
        print("🛠️ Setting up test data...")
        
        # 1. Employee (Waiter)
        email = f"waiter_{unique_id}@pronto.com"
        waiter = Employee(
            id=uuid.uuid4(),
            employee_code=f"W-{unique_id}",
            first_name="Waiter",
            last_name=unique_id,
            email=email,
            email_hash=hash_identifier(email), # Manually set hash
            role=Roles.WAITER.value,
            is_active=True
        )
        waiter.set_password("password123")
        db.add(waiter)
        
        # 2. Area
        area = Area(name=f"Area-{unique_id}", prefix=f"A{unique_id}"[:10])
        db.add(area)
        db.flush() # Get ID
        
        # 3. Tables (Raw SQL to avoid schema mismatch)
        table_a_id = uuid.uuid4()
        table_b_id = uuid.uuid4()
        table_c_id = uuid.uuid4()
        
        # Determine columns based on known DB schema from psql output
        # id, table_number, area_id, capacity, status, is_active, created_at, updated_at
        # qr_code is optional
        
        sql = text("""
            INSERT INTO pronto_tables (id, table_number, area_id, capacity, status, is_active, created_at, updated_at)
            VALUES (:id, :num, :area_id, 4, 'available', true, now(), now())
        """)
        
        db.execute(sql, {"id": table_a_id, "num": f"A-{unique_id}", "area_id": area.id})
        db.execute(sql, {"id": table_b_id, "num": f"B-{unique_id}", "area_id": area.id})
        db.execute(sql, {"id": table_c_id, "num": f"C-{unique_id}", "area_id": area.id})
        
        # 4. Customer
        customer = Customer(
            id=uuid.uuid4(),
            first_name=f"Cust-{unique_id}", # Model uses first_name/last_name not name
            email=f"cust_{unique_id}@test.com"
        )
        db.add(customer)
        db.flush()
        
        # 5. Session A on Table A
        session_a = DiningSession(
            id=uuid.uuid4(),
            customer_id=customer.id,
            table_id=table_a_id,
            table_number=f"A-{unique_id}",
            status=SessionStatus.OPEN.value,
            opened_at=datetime.now()
        )
        db.add(session_a)

        # 6. Session C on Table C
        session_c = DiningSession(
            id=uuid.uuid4(),
            customer_id=customer.id,
            table_id=table_c_id,
            table_number=f"C-{unique_id}",
            status=SessionStatus.OPEN.value,
            opened_at=datetime.now()
        )
        db.add(session_c)
        
        db.commit()
        
        
        data = {
            "waiter_email": waiter.email,
            "waiter_password": "password123",
            "table_a_id": str(table_a_id),
            "table_b_id": str(table_b_id),
            "table_b_number": f"B-{unique_id}",
            "session_a_id": str(session_a.id),
            "session_c_id": str(session_c.id),
        }
        print(f"✅ Data setup complete. Waiter: {waiter.email}")
        print(f"DEBUG: Script Salt: {os.getenv('PASSWORD_HASH_SALT')}")
        print(f"DEBUG: Generated Email Hash: {waiter.email_hash}")
        
        
    return data

def run_test(data):
    print("🚀 Verifying Endpoints...")
    
    # 1. Login
    print(f"Logging in as {data['waiter_email']}...")
    try:
        login_headers = {}
        internal_secret = os.getenv("PRONTO_INTERNAL_SECRET")
        if internal_secret:
            login_headers["X-Pronto-Internal-Auth"] = internal_secret
            
        res = requests.post(f"{API_BASE_URL}/employees/auth/login", json={
            "email": data['waiter_email'],
            "password": data['waiter_password']
        }, headers=login_headers)
        res.raise_for_status()
        token = res.json().get("data", {}).get("access_token")
        if not token: # Maybe wrapper is different? verify_feedback used direct service
             # Check response structure
             print(f"Login response: {res.json()}")
             token = res.json().get("access_token") # Based on auth.py lines 70-76 it returns success_response({...})
             # auth.py: success_response({"message":..., "employee":..., "access_token":...})
             # success_response format: {"status": "success", "data": {...}}
             if not token: 
                 token = res.json().get("data", {}).get("access_token")
        
        headers = {"Authorization": f"Bearer {token}", "X-Scope": "waiter"}
        print("✅ Login successful")
    except Exception as e:
        print(f"❌ Login failed: {e}")
        if hasattr(e, 'response') and e.response:
             print(e.response.text)
        return False

    # 2. Move Session A to Table B
    session_id = data['session_a_id']
    target_table_id = data['table_b_id']
    target_table_num = data['table_b_number']
    
    print(f"Testing Move Session {session_id} to Table {target_table_num}...")
    try:
        res = requests.post(
            f"{API_BASE_URL}/sessions/{session_id}/move-to-table",
            headers=headers,
            json={"table_id": target_table_id}
        )
        if res.status_code == 200:
            print(f"✅ Move successful: {res.json()}")
        else:
            print(f"❌ Move failed: {res.status_code} - {res.text}")
            return False
    except Exception as e:
        print(f"❌ Move request error: {e}")
        return False

    # 3. Merge Session A into Session C
    # Now Session A is on Table B.
    # We merge it into Session C (on Table C).
    session_c_id = data['session_c_id']
    print(f"Testing Merge Session {session_id} into {session_c_id}...")
    
    try:
        res = requests.post(
            f"{API_BASE_URL}/sessions/merge",
            headers=headers,
            json={"session_ids": [session_c_id, session_id]}
        )
        if res.status_code == 200:
            print(f"✅ Merge successful: {res.json()}")
        else:
            print(f"❌ Merge failed: {res.status_code} - {res.text}")
            return False
    except Exception as e:
        print(f"❌ Merge request error: {e}")
        return False
        
    return True

if __name__ == "__main__":
    try:
        test_data = setup_test_data()
        if run_test(test_data):
            print("✅✅ ALL TESTS PASSED ✅✅")
            sys.exit(0)
        else:
            print("❌❌ TESTS FAILED ❌❌")
            sys.exit(1)
    except Exception as e:
        print(f"❌ Critical error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
