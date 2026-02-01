#!/usr/bin/env python3
"""Fix all cashier passwords in database using proper hashing from shared.security."""

import os
import sys

# Add project to path for shared imports
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(project_root, "build"))


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

from shared.security import hash_credentials, hash_identifier

# Use the standard default password from environment
DEFAULT_PASSWORD = os.getenv("SEED_EMPLOYEE_PASSWORD", "ChangeMe!123")

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

print(f"Using password: {DEFAULT_PASSWORD}")

# Cashier emails from test data
cashier_emails = [
    ("laura.cajera@cafeteria.test", "Laura Cajera"),
    ("roberto.cajero@cafeteria.test", "Roberto Cajero"),
]

for email, name in cashier_emails:
    email_hash = hash_identifier(email)
    new_auth_hash = hash_credentials(email, DEFAULT_PASSWORD)

    cursor.execute(
        """
        UPDATE pronto_employees
        SET auth_hash = %s, allow_scopes = %s
        WHERE email_hash = %s
        """,
        (new_auth_hash, '["cashier"]', email_hash),
    )

    if cursor.rowcount > 0:
        print(f"✓ Updated password for {name} ({email})")
    else:
        # Try to find by role and name
        cursor.execute(
            "SELECT id, email_encrypted, email_hash FROM pronto_employees WHERE role = 'cashier' LIMIT 1"
        )
        row = cursor.fetchone()
        if row:
            print(f"! {name} not found by email")
            print(f"  Found cashier: ID={row[0]}, Email={row[1]}")
            print(f"  Email hash in DB: {row[2][:30]}...")
            print(f"  Expected hash:    {email_hash[:30]}...")
        else:
            print(f"✗ {name} not found in database")

cursor.execute(
    "SELECT id, email_encrypted, role, auth_hash IS NOT NULL as has_password FROM pronto_employees WHERE role = 'cashier'"
)
print("\nCashier employees after fix:")
for row in cursor.fetchall():
    print(f"  ID: {row[0]}, Email: {row[1]}, Has password: {row[3]}")

cursor.close()
conn.close()
print("\n✅ Done")
