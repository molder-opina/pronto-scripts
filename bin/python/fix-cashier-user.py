#!/usr/bin/env python3
"""Fix cashier user: update email and password using pronto_shared.security."""

import os
import sys

# Add project to path for shared imports
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Ensure pronto_shared is importable
try:
    import pronto_shared
except ImportError:
    raise ImportError(
        "pronto_shared package not found. Install it from pronto-libs repo:\n"
        "cd ../pronto-libs && pip install -e ."
    )


# Load environment variables
def load_env_file(filepath):
    if not os.path.exists(filepath):
        return
    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip())


load_env_file(os.path.join(project_root, "config", "secrets.env"))

import psycopg2

from pronto_shared.security import hash_credentials, hash_identifier

postgres_host = os.getenv("POSTGRES_HOST", "localhost")
postgres_port = os.getenv("POSTGRES_PORT", "5432")
postgres_user = os.getenv("POSTGRES_USER", "pronto")
postgres_password = os.getenv("POSTGRES_PASSWORD", "pronto123")
postgres_db = os.getenv("POSTGRES_DB", "pronto")

conn = psycopg2.connect(
    host=postgres_host,
    port=postgres_port,
    user=postgres_user,
    password=postgres_password,
    database=postgres_db,
)
conn.autocommit = True
cursor = conn.cursor()

# Get the existing cashier (ID 24)
cursor.execute("SELECT id, email_hash, email_encrypted FROM pronto_employees WHERE id = 24")
row = cursor.fetchone()
if row:
    print(f"Found cashier ID {row[0]}")
    print(f"  Current email_hash: {row[1][:30]}...")
    print(f"  Current email: {row[2]}")

# Update the cashier with laura.cajera@cafeteria.test
email = "laura.cajera@cafeteria.test"
default_password = os.getenv("SEED_EMPLOYEE_PASSWORD", "ChangeMe!123")

email_hash = hash_identifier(email)
auth_hash = hash_credentials(email, default_password)

print(f"\nUpdating to:")
print(f"  Email: {email}")
print(f"  Password: {default_password}")
print(f"  Email hash: {email_hash[:30]}...")
print(f"  Auth hash: {auth_hash[:30]}...")

cursor.execute(
    """
    UPDATE pronto_employees
    SET email_hash = %s,
        auth_hash = %s,
        email_encrypted = %s,
        name_encrypted = %s,
        allow_scopes = %s
    WHERE id = 24
""",
    (email_hash, auth_hash, email, "Laura Cajera", '["cashier"]'),
)

print(f"\nRows affected: {cursor.rowcount}")

# Verify
cursor.execute(
    "SELECT id, email_encrypted, email_hash, role, allow_scopes FROM pronto_employees WHERE id = 24"
)
row = cursor.fetchone()
if row:
    print(f"\nUpdated cashier:")
    print(f"  ID: {row[0]}")
    print(f"  Email: {row[1]}")
    print(f"  email_hash: {row[2][:30]}...")
    print(f"  role: {row[3]}")
    print(f"  allow_scopes: {row[4]}")

cursor.close()
conn.close()
print("\n✅ Done")
