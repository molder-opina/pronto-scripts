#!/usr/bin/env python3
"""Create cashier users with correct emails in database using app's hashing."""

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

# Cashier emails from test data
cashiers = [
    ("laura.cajera@cafeteria.test", "Laura Cajera"),
    ("roberto.cajero@cafeteria.test", "Roberto Cajero"),
]

default_password = os.getenv("SEED_EMPLOYEE_PASSWORD", "ChangeMe!123")

for email, name in cashiers:
    email_hash = hash_identifier(email)
    auth_hash = hash_credentials(email, default_password)

    # Check if employee exists
    cursor.execute(
        "SELECT id, email_hash FROM pronto_employees WHERE email_hash = %s", (email_hash,)
    )
    existing = cursor.fetchone()

    if existing:
        print(f"✓ Cashier {name} ({email}) already exists")
        # Update password and scopes
        cursor.execute(
            """UPDATE pronto_employees
               SET auth_hash = %s, allow_scopes = %s
               WHERE email_hash = %s""",
            (auth_hash, '["cashier"]', email_hash),
        )
        print(f"  ✓ Updated password and scopes")
    else:
        # Insert new cashier
        print(f"✗ Cashier {name} ({email}) not found in DB")
        print(f"  Creating new cashier...")
        cursor.execute(
            """
            INSERT INTO pronto_employees
            (email_hash, auth_hash, role, is_active, name_encrypted, email_encrypted, allow_scopes)
            VALUES (%s, %s, 'cashier', true, %s, %s, '["cashier"]')
            """,
            (email_hash, auth_hash, name, email),
        )
        print(f"  ✓ Created cashier {name}")

print("\n=== Testing login with laura.cajera@cafeteria.test ===")
test_email = "laura.cajera@cafeteria.test"
test_hash = hash_identifier(test_email)
test_auth = hash_credentials(test_email, default_password)

cursor.execute(
    "SELECT id, role, auth_hash FROM pronto_employees WHERE email_hash = %s", (test_hash,)
)
row = cursor.fetchone()
if row:
    print(f"Found employee ID: {row[0]}, Role: {row[1]}")
    print(f"Stored auth_hash: {row[2][:30]}...")
    print(f"Computed auth_hash: {test_auth[:30]}...")
    if row[2] == test_auth:
        print("✅ Password matches!")
    else:
        print("❌ Password mismatch!")
else:
    print("❌ Employee not found")

cursor.close()
conn.close()
print("\n✅ Done")
