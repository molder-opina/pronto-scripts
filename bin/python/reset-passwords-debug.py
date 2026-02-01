#!/usr/bin/env python3
"""
Script to reset passwords for all employees to the default password and list their credentials.
Useful for debugging login issues.
"""

import os
import sys

from shared.config import load_config
from shared.db import get_session, init_engine
from shared.models import Employee
from shared.security import hash_credentials

DEFAULT_PASSWORD = os.getenv("SEED_EMPLOYEE_PASSWORD", "ChangeMe!123")


def reset_passwords():
    # Initialize DB
    config = load_config("pronto-script")
    init_engine(config)

    print(f"🔄 Resetting passwords to '{DEFAULT_PASSWORD}'...")

    with get_session() as session:
        employees = session.query(Employee).all()

        print(f"\nFound {len(employees)} employees:")
        print("-" * 60)
        print(f"{'Role':<15} | {'Name':<25} | {'Email':<30}")
        print("-" * 60)

        for emp in employees:
            # Reset password
            emp.auth_hash = hash_credentials(emp.email, DEFAULT_PASSWORD)

            print(f"{emp.role:<15} | {emp.name:<25} | {emp.email:<30}")

        session.commit()
        print("-" * 60)
        print(f"\n✅ All passwords have been reset to: {DEFAULT_PASSWORD}")


if __name__ == "__main__":
    reset_passwords()
