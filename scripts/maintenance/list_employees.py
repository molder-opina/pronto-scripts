import os
import sys

# Add shared to path
project_root = os.path.dirname(os.path.abspath(__file__))
sys.path.append(project_root)
sys.path.append(os.path.join(project_root, "build"))

from pronto_shared.db import get_session
from pronto_shared.models import Employee


def list_employees():
    with get_session() as db:
        employees = db.query(Employee).all()
        print(f"{'ID':<5} | {'Name':<20} | {'Email':<30} | {'Role':<15} | {'Active':<10}")
        print("-" * 90)
        for e in employees:
            print(f"{e.id:<5} | {e.name:<20} | {e.email:<30} | {e.role:<15} | {e.is_active:<10}")


if __name__ == "__main__":
    list_employees()
