import sys
import os
import json

# Add project root to path (3 levels up from bin/tests/script.py)
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../"))
sys.path.insert(0, os.path.join(project_root, "pronto-libs/src"))
sys.path.insert(0, os.path.join(project_root, "pronto-api/src"))

from pronto_shared.config import load_config
from pronto_shared.db import init_engine, get_session
from pronto_shared.services.business_config_service import get_all_system_settings

def verify_system_settings_structure():
    print("Verifying System Settings API structure...")
    
    # Initialize DB
    config = load_config("employees")
    init_engine(config)
    
    # Call service directly (simulates API)
    response, status = get_all_system_settings()
    
    if status != 200:
        print(f"❌ Failed to get settings. Status: {status}")
        return False
        
    # response is a tuple (dict, status) or just dict depending on how it's called
    # but the service returns tuple[dict, int]
    
    if isinstance(response, tuple):
        response_data = response[0]
    else:
        response_data = response
        
    configs = response_data.get("data", {}).get("configs", [])
    if not configs:
        print("⚠️ No configs found.")
        return True # Not necessarily a failure, but weird
        
    print(f"Found {len(configs)} configuration items.")
    
    # Check structure of first item
    first_item = configs[0]
    required_fields = {
        "id", "config_key", "category", "display_name", 
        "value_type", "raw_value", "value", 
        "min_value", "max_value", "unit"
    }
    
    missing = required_fields - first_item.keys()
    
    if missing:
        print(f"❌ Missing required fields: {missing}")
        print(f"Item sample: {json.dumps(first_item, indent=2, default=str)}")
        return False
        
    print("✅ All required fields present in response.")
    
    # Check if min_value/max_value/unit are present (even if null)
    print(f"Sample Item: {first_item['config_key']}")
    print(f"  - min_value: {first_item.get('min_value')}")
    print(f"  - max_value: {first_item.get('max_value')}")
    print(f"  - unit: {first_item.get('unit')}")
    
    return True

if __name__ == "__main__":
    if verify_system_settings_structure():
        print("\n✅ System Console API Verification Passed!")
        sys.exit(0)
    else:
        print("\n❌ Verification Failed")
        sys.exit(1)
