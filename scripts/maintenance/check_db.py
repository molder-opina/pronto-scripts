import os
import sys

# Add build directory to path
sys.path.append(os.path.join(os.getcwd(), "build"))

from shared.database import SessionLocal
from shared.models import Employee


def check_employees():
    session = SessionLocal()
    employees = session.query(Employee).all()
    print("EMPLOYEE LIST:")
    for e in employees:
        print(f"- {e.name}: {e.email} (Role: {e.role})")
    session.close()


if __name__ == "__main__":
    check_employees()
