import os
import sys

# Add app context
sys.path.append("/opt/pronto")

from employees_app.app import create_app
from shared.db import get_session
from shared.models import Employee


def list_employees():
    app = create_app()
    with app.app_context(), get_session() as session:
        employees = session.query(Employee).all()
        print("-" * 60)
        print(f"{'ID':<5} | {'Role':<10} | {'Email':<30} | {'Active'}")
        print("-" * 60)
        for e in employees:
            print(f"{e.id:<5} | {e.role:<10} | {e.email:<30} | {e.is_active}")
        print("-" * 60)


if __name__ == "__main__":
    list_employees()
