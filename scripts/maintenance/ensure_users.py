import json
import os
import sys

# Add build to path
sys.path.insert(0, "build")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from shared.models import Employee
from shared.security import encrypt_string, hash_credentials, hash_identifier

DB_URL = "postgresql://pronto:pronto123@localhost:5432/pronto"

try:
    engine = create_engine(DB_URL)
    Session = sessionmaker(bind=engine)
    session = Session()

    # Users to ensure
    # email, name, role
    target_users = [
        ("waiter@cafeteria.test", "QA Waiter", "waiter"),
        ("chef@cafeteria.test", "QA Chef", "chef"),
        ("cashier@cafeteria.test", "QA Cashier", "cashier"),
    ]

    for email, name, role in target_users:
        email_hash = hash_identifier(email)
        print(f"Checking {email}...")
        emp = session.query(Employee).filter_by(email_hash=email_hash).first()

        if emp:
            print(f"  Found {email}. Updating password...")
            emp.auth_hash = hash_credentials(email, "ChangeMe!123")
            # Ensure scopes are correct
            if role == "waiter":
                emp.allow_scopes = json.dumps(["waiter", "cashier"])
                emp.additional_roles = '["cashier"]'
            elif role == "chef":
                emp.allow_scopes = json.dumps(["chef"])
            elif role == "cashier":
                emp.allow_scopes = json.dumps(["waiter", "cashier"])
        else:
            print(f"  Creating {email}...")
            emp = Employee(role=role)
            emp.name = name  # setter handles encryption if model uses hybrid property?
            # Model definition in shared/models.py might use name_encrypted
            # Let's use name setter if available, or direct column if needed.
            # Looking at init-db.md Option 4:
            # emp.name_encrypted = encrypt_string(name)
            # But seed.py uses: employee.name = name.
            # I will use direct assignment which likely maps to hybrid property or setter.
            # But just in case, I will try to support both.
            try:
                emp.name = name
                emp.email = email
            except:
                # If setter fails or not present (e.g. if I need to use _encrypted)
                emp.name_encrypted = encrypt_string(name)
                emp.email_encrypted = encrypt_string(email)

            emp.email_hash = email_hash
            emp.auth_hash = hash_credentials(email, "ChangeMe!123")

            if role == "waiter":
                emp.allow_scopes = json.dumps(["waiter", "cashier"])
                emp.additional_roles = '["cashier"]'
            elif role == "chef":
                emp.allow_scopes = json.dumps(["chef"])
            elif role == "cashier":
                emp.allow_scopes = json.dumps(["waiter", "cashier"])

            session.add(emp)

    session.commit()
    print("✅ Users ensured and passwords set.")

except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
