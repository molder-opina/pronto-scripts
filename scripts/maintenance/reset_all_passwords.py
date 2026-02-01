import os
import sys

# Add build to path
sys.path.insert(0, "build")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from shared.models import Employee
from shared.security import hash_credentials

# DB Connection
# Try Postgres first, fallback to SQLite if needed?
# Assuming Postgres as per init-db.md
DB_URL = "postgresql://pronto:pronto123@localhost:5432/pronto"

try:
    engine = create_engine(DB_URL)
    Session = sessionmaker(bind=engine)
    session = Session()

    employees = session.query(Employee).all()
    print(f"Found {len(employees)} employees in DB.")

    if not employees:
        print("No employees found! DB might be empty.")
        sys.exit(1)

    for emp in employees:
        print(f"Resetting password for: {emp.email} ({emp.role})")
        # Password hardcoded to 'ChangeMe!123'
        emp.auth_hash = hash_credentials(emp.email, "ChangeMe!123")

    session.commit()
    print("✅ All passwords reset to 'ChangeMe!123'")

except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
