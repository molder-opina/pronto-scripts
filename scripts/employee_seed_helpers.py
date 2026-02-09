"""
Employee seed helpers - extracted from seed.py for interactive seeding.

These functions are used by seed_interactive.py to create employees
with proper encryption and password hashing.
"""

from __future__ import annotations

import json
import os

from sqlalchemy import select

from pronto_shared.models import Employee
from pronto_shared.security import hash_credentials, hash_identifier
from pronto_shared.validation import validate_password


def get_or_create_employee(
    session,
    email: str,
    name: str,
    role: str,
    default_password: str,
    *,
    force_password_reset: bool = False,
    additional_roles: str | None = None,
) -> Employee:
    """Get existing employee or create new one.

    Args:
        additional_roles: JSON string array of additional roles (e.g., '["cashier"]')
                         By default, waiters get '["cashier"]' to enable payment capability
    """
    email_hash = hash_identifier(email)
    employee = session.execute(
        select(Employee).where(Employee.email_hash == email_hash)
    ).scalar_one_or_none()

    # Set default additional_roles for waiters
    if additional_roles is None and role == "waiter":
        additional_roles = '["cashier"]'

    if employee:
        # Update existing
        employee.name = name
        employee.role = role
        employee.additional_roles = additional_roles
        if force_password_reset:
            validate_password(default_password)
            employee.auth_hash = hash_credentials(employee.email, default_password)
        
        # Set scopes based on role
        if role == "system":
            new_scopes = ["system", "admin", "waiter", "chef", "cashier"]
        elif role == "admin":
            new_scopes = ["admin", "waiter", "chef", "cashier"]
        elif role in ("waiter", "cashier"):
            new_scopes = ["waiter", "cashier"]
        elif role == "chef":
            new_scopes = ["chef"]
        else:
            new_scopes = []
        employee.allow_scopes = json.dumps(new_scopes)
    else:
        # Create new
        employee = Employee(role=role, additional_roles=additional_roles)
        employee.name = name
        employee.email = email
        validate_password(default_password)
        employee.auth_hash = hash_credentials(employee.email, default_password)
        
        # Set scopes based on role
        if role == "system":
            new_scopes = ["system", "admin", "waiter", "chef", "cashier"]
        elif role == "admin":
            new_scopes = ["admin", "waiter", "chef", "cashier"]
        elif role in ("waiter", "cashier"):
            new_scopes = ["waiter", "cashier"]
        elif role == "chef":
            new_scopes = ["chef"]
        else:
            new_scopes = []
        employee.allow_scopes = json.dumps(new_scopes)
        session.add(employee)

    return employee


def assign_missing_employee_identity(session) -> int:
    """Fill name/email for employees missing identity data."""
    seed_password = os.getenv("SEED_EMPLOYEE_PASSWORD", "ChangeMe!123")
    validate_password(seed_password)

    employees = session.execute(select(Employee)).scalars().all()
    used_emails = {e.email.lower() for e in employees if e.email}

    role_defaults = {
        "system": ("Admin General", "admin"),
        "admin": ("Admin", "admin"),
        "waiter": ("Mesero", "waiter"),
        "chef": ("Chef", "chef"),
        "cashier": ("Cajero", "cashier"),
    }

    def unique_email(base_local: str) -> tuple[str, int]:
        suffix = 1
        candidate = f"{base_local}@cafeteria.test"
        while candidate.lower() in used_emails:
            suffix += 1
            candidate = f"{base_local}{suffix}@cafeteria.test"
        used_emails.add(candidate.lower())
        return candidate, suffix

    updated = 0
    for employee in employees:
        current_name = employee.name
        current_email = employee.email
        if current_name and current_email:
            continue

        role = (employee.role or "").strip().lower()
        default_name, base_local = role_defaults.get(role, ("Empleado", "empleado"))

        if not current_email:
            new_email, suffix = unique_email(base_local)
            employee.email = new_email
            # Ensure login works for seeded identities.
            employee.auth_hash = hash_credentials(employee.email, seed_password)
            if not current_name:
                employee.name = (
                    default_name if suffix == 1 else f"{default_name} {suffix}"
                )
            updated += 1
            continue

        if not current_name:
            employee.name = default_name
            updated += 1

    return updated
