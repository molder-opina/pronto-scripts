import sys
import os
import json
from datetime import datetime

# Add path to include pronto_shared
sys.path.append(os.path.join(os.path.dirname(__file__), "../../../pronto-libs/src"))
sys.path.append(os.path.join(os.path.dirname(__file__), "../../../pronto-employees/src"))
# Adjusted import path for API routes
sys.path.append(os.path.join(os.path.dirname(__file__), "../../../pronto-api/src"))

from pronto_shared.config import load_config
from pronto_shared.db import init_engine, get_session
from pronto_shared.models import SystemSetting
from pronto_shared.services.business_config_service import get_all_system_settings, update_system_setting

from flask import Flask
from unittest.mock import patch

def run_verification():
    # Load env
    config = load_config("employees")
    print(f"DEBUG: DB Host: {config.db_host}, DB Port: {config.db_port}, DB Name: {config.db_name}")
    print(f"DEBUG: URI: {config.sqlalchemy_uri}")
    init_engine(config)
    
    # Debug raw SQL
    from sqlalchemy import text
    from sqlalchemy import select
    from pronto_shared.models import SystemSetting

    with get_session() as s:
        result = s.execute(text("SELECT count(*) FROM pronto_system_settings")).scalar()
        print(f"DEBUG: Count via raw SQL: {result}")
        
        orm_result = s.execute(select(SystemSetting)).scalars().all()
        print(f"DEBUG: Count via ORM direct: {len(orm_result)}")
        
    app = Flask(__name__)
    
    with app.test_request_context():
        # Test 1: List all settings
        print("Testing get_all_system_settings()...")
        data, status = get_all_system_settings()
        
        if status != 200:
            print(f"FAILURE: get_all returned status {status}")
            return
            
        # success_response wraps payload in "data"
        configs = data.get("data", {}).get("configs", [])
        print(f"  Found {len(configs)} settings.")
        
        waiter_config = next((c for c in configs if c["config_key"] == "waiter_can_collect"), None)
        if not waiter_config:
            print("FAILURE: 'waiter_can_collect' setting not found in list!")
            return
            
        print(f"  Found 'waiter_can_collect' (ID: {waiter_config['id']}), Current Value: {waiter_config['value']}")
        config_id = waiter_config['id']
        current_val = waiter_config['value'] # Should be boolean
        
        # Test 2: Update setting
        new_val = not current_val
        print(f"Testing update_system_setting({config_id}, {new_val})...")
        
        # Mock get_employee_id if needed (though service doesn't strictly require it based on my implementation)
        updated_data, status = update_system_setting(config_id, str(new_val).lower())
        
        if status != 200:
            print(f"FAILURE: update returned status {status}: {updated_data}")
            return
            
        updated_val = updated_data.get("data", {}).get("config", {}).get("value")
        print(f"  Update success. New Value: {updated_val}")
        
        if updated_val != new_val:
            print(f"FAILURE: Value mismatch. Expected {new_val}, got {updated_val}")
            return
            
        # Revert
        print("Reverting value...")
        update_system_setting(config_id, str(current_val).lower())
        print("SUCCESS: System Settings API verified.")

if __name__ == "__main__":
    run_verification()
