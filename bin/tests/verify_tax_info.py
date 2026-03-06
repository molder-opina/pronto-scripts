
import sys
import os
import requests
import json
import uuid

# Configuration
API_BASE_URL = "http://localhost:6082"  # standard API port
CLIENT_API_URL = "http://localhost:6080" # client app might proxy or we hit API directly

# We will hit the API directly for backend verification
# But client auth endpoints are on 6082 under /api usually if routed through API service
# Wait, auth.py is in pronto-client. pronto-client runs on 6080.
# So I should target localhost:6080 for auth.

BASE_URL = "http://localhost:6080"
API_URL = f"{BASE_URL}/api"

def run_test():
    print("Starting Tax Info Verification...")
    
    # 1. Register new customer
    unique_id = str(uuid.uuid4())[:8]
    email = f"taxuser_{unique_id}@test.com"
    password = "password123"
    name = f"Tax User {unique_id}"
    
    print(f"Registering user: {email}")
    session = requests.Session()
    
    # 0. Get CSRF Token
    print("Fetching CSRF token...")
    try:
        # Get the home page to get the cookie and token
        res_home = session.get(BASE_URL)
        
        import re
        csrf_token = None
        # Try to find in meta tag with flexible regex
        # Matches <meta name="csrf-token" content="..."> with optional spaces and self-closing slash
        match = re.search(r'<meta\s+name="csrf-token"\s+content="([^"]+)"\s*/?>', res_home.text)
        if match:
            csrf_token = match.group(1)
            print(f"Found CSRF token: {csrf_token[:10]}...")
        else:
            print("Could not find CSRF token in meta tag. Trying to proceed with cookies only.")
            
        if csrf_token:
            session.headers.update({"X-CSRFToken": csrf_token})
            
    except Exception as e:
        print(f"Failed to get CSRF token: {e}")
        return False

    reg_payload = {
        "name": name,
        "email": email,
        "password": password,
        "phone": "5512345678"
    }
    
    try:
        res = session.post(f"{API_URL}/register", json=reg_payload)
        if res.status_code != 201:
            print(f"Registration failed: {res.status_code} {res.text}")
            return False
            
        print("Registration successful.")
        
        # 1.5 Refresh CSRF Token after login (session change)
        print("Refreshing CSRF token after login...")
        try:
             res_home = session.get(BASE_URL)
             import re
             csrf_token = None
             match = re.search(r'<meta\s+name="csrf-token"\s+content="([^"]+)"\s*/?>', res_home.text)
             if match:
                 csrf_token = match.group(1)
                 print(f"Found new CSRF token: {csrf_token[:10]}...")
                 session.headers.update({"X-CSRFToken": csrf_token})
             else:
                 print("Could not find new CSRF token.")
        except Exception as e:
             print(f"Failed to refresh CSRF token: {e}")

        # 2. Update Profile with Tax Info
        tax_info = {
            "tax_id": "XAXX010101000",
            "tax_name": f"Empresa {unique_id} SA de CV",
            "tax_email": f"factura_{unique_id}@empresa.com",
            "tax_address": "06600"
        }
        
        print("Updating profile with tax info...")
        res = session.put(f"{API_URL}/me", json=tax_info)
        
        if res.status_code != 200:
            print(f"Profile update failed: {res.status_code} {res.text}")
            return False
            
        data = res.json()
        customer = data.get("customer", {})
        
        # Verify response contains tax info
        if customer.get("tax_id") != tax_info["tax_id"]:
            print(f"Update response mismatch: {customer.get('tax_id')} != {tax_info['tax_id']}")
            return False
            
        print("Profile update successful. Response matches.")
        
        # 3. Verify Session Persistence (GET /me)
        print("Verifying session persistence...")
        res = session.get(f"{API_URL}/me")
        if res.status_code != 200:
             print(f"GET /me failed: {res.status_code} {res.text}")
             return False
             
        data = res.json()
        customer = data.get("customer", {})
        if customer.get("tax_id") != tax_info["tax_id"]:
            print(f"Session verif mismatch: {customer.get('tax_id')} != {tax_info['tax_id']}")
            return False
            
        print("Session persistence verified.")
        
        # 4. (Optional) Verify Ticket Generation
        # This requires creating a dining session and order, which might be complex via generic API 
        # without setting up tables etc. 
        # However, checking the profile update persistence is the detailed part of this task.
        # The ticket generation logic is unit-testable or manual verification.
        # Let's try to verify via a known session if possible, but for now this covers the main task.
        
        return True
        
    except Exception as e:
        print(f"Test failed with exception: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    if run_test():
        print("✅ Tax Info Verification PASSED")
        sys.exit(0)
    else:
        print("❌ Tax Info Verification FAILED")
        sys.exit(1)
