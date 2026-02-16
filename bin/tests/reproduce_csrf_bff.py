import requests
import os

# Configuration
API_URL = "http://localhost:6082"
# Endpoint that requires CSRF (POST)
TARGET_URL = f"{API_URL}/api/orders" 

def test_csrf_rejection():
    print(f"Testing POST to {TARGET_URL} without CSRF token...")
    try:
        # Simulate a BFF request (no cookie/session initially, just payload)
        response = requests.post(
            TARGET_URL,
            json={"items": [], "total": 0},
            headers={"Content-Type": "application/json"}
        )
        
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")
        
        if response.status_code == 400 and "CSRF" in response.text:
            print("SUCCESS: CSRF rejection verified.")
        elif response.status_code == 404:
            print("WARNING: Endpoint not found (404). Check URL.")
        else:
            print(f"FAILURE: Expected 400 CSRF error, got {response.status_code}")

    except Exception as e:
        print(f"ERROR: {e}")

def test_csrf_bypass():
    secret = os.getenv("PRONTO_INTERNAL_SECRET", "120d88e0cea0c97975e99901650132968f1b554c76d16814eeef2c4ce905aa89")
    print(f"\nTesting POST to {TARGET_URL} WITH X-Pronto-Internal-Auth={secret[:6]}...")
    try:
        response = requests.post(
            TARGET_URL,
            json={"items": [], "total": 0},
            headers={
                "Content-Type": "application/json",
                "X-Pronto-Internal-Auth": secret
            }
        )
        
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.text}")

        # If we get anything other than 400 CSRF error, the bypass worked.
        # Likely 401 (Auth required) or 422 (Schema validation)
        if response.status_code != 400:
            print(f"SUCCESS: CSRF bypass verified (Got {response.status_code}).")
        else:
            print("FAILURE: Still got 400 CSRF error.")

    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    test_csrf_rejection()
    test_csrf_bypass()
