
import sys
from pronto_shared.db import get_session, init_engine
from pronto_shared.config import load_config
from pronto_shared.services.auth_service import auth_service
from pronto_shared.models import Employee
from sqlalchemy import select

def reset():
    print("Resetting password...")
    config = load_config("api")
    init_engine(config)
    
    with get_session() as session:
        # We need to find employee. We can use email_hash if we know it, or find by legacy query if model not fully working?
        # But auth_service uses email_hash.
        from pronto_shared.security import hash_identifier
        email = "juan@pronto.com"
        h = hash_identifier(email)
        
        emp = session.execute(select(Employee).where(Employee.email_hash == h)).scalars().first()
        
        if not emp:
            print(f"Employee {email} not found by hash.")
            # Try to find by id if possible? Or raw sql?
            # Or iterate all?
            # Let's try raw sql find ID
            from sqlalchemy import text
            res = session.execute(text("SELECT id FROM pronto_employees WHERE email = :e"), {"e": email}).fetchone()
            if res:
                emp = session.get(Employee, res[0])
            else:
                print("Not found by email either.")
                return

        print(f"Found employee {emp.id}. Resetting password to '1234'.")
        # Ensure email property works (decrypts)
        try:
            print(f"Decrypted email: {emp.email}")
        except Exception as e:
            print(f"Error decrypting email: {e}")
            # If decrypt fails, verify_credentials might fail if it uses property
            # Actually verify_credentials(email, ...) uses passed email.
            # But hash_credentials(username, ...) uses username.
            # set_password uses emp.email.
            # If emp.email is garbage/empty, hash will be wrong.
            
        # Verify encryption
        if not emp.email:
             print("WARNING: emp.email is empty. Manually setting it before hash.")
             # This sets email_encrypted and email_hash
             emp.email = email
             session.flush()
             
        # Inspect schema
        print("--- SCHEMA INTROSPECTION ---")
        from sqlalchemy import text
        rows = session.execute(text("select column_name, data_type from information_schema.columns where table_name = 'pronto_employees' and column_name = 'id'")).fetchall()
        print(f"DB ID Column: {rows}")
        
        print(f"Model ID Type: {Employee.id.type}")
        print("----------------------------")
        
        auth_service.set_password(emp, "1234")
        session.commit()
        print("Password reset done.")

        print("Testing authentication...")
        try:
            res = auth_service.authenticate("juan@pronto.com", "1234")
            if res.success:
                print("Auth SUCCESS!")
            else:
                print(f"Auth FAILED: {res.error_message} ({res.error_code})")
        except Exception as e:
            print(f"Auth CRASHED: {e}")

if __name__ == "__main__":
    reset()
