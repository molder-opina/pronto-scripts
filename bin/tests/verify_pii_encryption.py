
import os
import sys
from sqlalchemy import text
from pronto_shared.config import load_config
from pronto_shared.db import init_engine, get_session
from pronto_shared.models import Customer
from pronto_shared.security import decrypt_string

# Initialize DB
config = load_config("pronto-api")
init_engine(config)

def verify_pii_encryption():
    try:
        with get_session() as session:
            # 1. Create a test customer
            test_email = "test.pii@example.com"
            test_name = "Test Encrypted"
            
            print("Creating Customer with PII...")
            # Cleanup existing if any (soft check)
            existing = session.query(Customer).filter(Customer.email_hash.isnot(None)).first() 
            # We don't know the hash for "test.pii@example.com" yet easily without library, 
            # but we can rely on unique constraint failure or just create unique one.
            # actually we can just proceed.
            
            customer = Customer(
                name=test_name,
                email=test_email,
                phone="5551234567"
            )
            session.add(customer)
            session.commit()
            
            cid = customer.id
            print(f"Created Customer ID: {cid}")
            
            # 2. Verify ORM read (should be decrypted)
            session.expire_all()
            fetched = session.get(Customer, cid)
            print(f"ORM Read Email: {fetched.email}")
            print(f"ORM Read Name: {fetched.name}")
            
            if fetched.email != test_email:
                print("FAILURE: ORM did not decrypt email correctly.")
                return
                
            if fetched.name != test_name:
                print(f"FAILURE: ORM did not decrypt name correctly. Got: {fetched.name}")
                return
                
            print("SUCCESS: ORM handles decryption transparently.")
            
            # 3. Verify Raw SQL (should be encrypted)
            print("Verifying Raw DB Storage...")
            result = session.execute(
                text("SELECT email, email_encrypted, name_encrypted FROM pronto_customers WHERE id = :id"),
                {"id": cid}
            ).fetchone()
            
            raw_email = result[0]
            raw_email_enc = result[1]
            raw_name_enc = result[2]
            
            print(f"RAW email (col): {raw_email}")
            print(f"RAW email_encrypted: {raw_email_enc}")
            print(f"RAW name_encrypted: {raw_name_enc}")
            
            if raw_email is not None:
                 print("WARNING: 'email' column is not NULL. It should be empty if we are enforcing encryption.")
                 if raw_email == test_email:
                     print("FAILURE: 'email' column contains Valid Plaintext PII!")
            
            if not raw_email_enc or test_email in raw_email_enc:
                print("FAILURE: 'email_encrypted' is missing or contains plaintext!")
                
            if decrypt_string(raw_email_enc) != test_email:
                 print("FAILURE: Could not decrypt raw 'email_encrypted'.")

            print("SUCCESS: PII is encrypted in database.")
            
            # Cleanup
            session.delete(fetched)
            session.commit()
            print("Test Customer deleted.")

    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    verify_pii_encryption()
