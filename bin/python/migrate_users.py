
import sys
import os
from sqlalchemy import text

# Add pronto-libs to path (inside container it's at /opt/pronto/pronto-libs or site-packages)
# The image installs it to site-packages.
from pronto_shared.db import get_session, init_engine
from pronto_shared.config import load_config
from pronto_shared.security import encrypt_string, hash_credentials, hash_identifier

def migrate_users():
    print("Starting user migration...")
    config = load_config("api")
    init_engine(config)
    
    with get_session() as session:
        # Fetch employees with missing encrypted data
        # We assume existing columns: email, first_name, last_name, pin
        # New columns: email_encrypted, name_encrypted, auth_hash, email_hash
        
        result = session.execute(text("SELECT id, email, first_name, last_name, pin FROM pronto_employees WHERE auth_hash IS NULL"))
        employees = result.fetchall()
        
        for emp in employees:
            emp_id = emp[0]
            email = emp[1]
            first_name = emp[2]
            last_name = emp[3]
            pin = emp[4]
            
            full_name = f"{first_name} {last_name}".strip()
            password = pin if pin else "1234" # Default if no pin
            
            print(f"Migrating employee {emp_id} ({email})...")
            
            email_enc = encrypt_string(email)
            name_enc = encrypt_string(full_name)
            email_hash = hash_identifier(email)
            auth_hash = hash_credentials(email, password)
            
            sql = text("""
                UPDATE pronto_employees 
                SET email_encrypted = :ee,
                    name_encrypted = :ne,
                    email_hash = :eh,
                    auth_hash = :ah
                WHERE id = :id
            """)
            
            session.execute(sql, {
                "ee": email_enc,
                "ne": name_enc,
                "eh": email_hash,
                "ah": auth_hash,
                "id": emp_id
            })
            
        session.commit()
        print(f"Migrated {len(employees)} employees.")

if __name__ == "__main__":
    migrate_users()
