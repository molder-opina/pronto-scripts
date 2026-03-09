#!/usr/bin/env python3
"""Update cashier password using proper hashing from pronto_shared.security."""

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

email = "laura.cajera@cafeteria.test"
default_password = os.getenv("SEED_EMPLOYEE_PASSWORD", "ChangeMe!123")

email_hash = hash_identifier(email)
auth_hash = hash_credentials(email, default_password)

print(f"Email: {email}")
print(f"Password: {default_password}")
print(f"Email hash: {email_hash[:30]}...")
print(f"Auth hash: {auth_hash[:30]}...")

# Check current state
cursor.execute(
    "SELECT id, role, auth_hash FROM pronto_employees WHERE email_hash = %s", (email_hash,)
)
row = cursor.fetchone()
if row:
    print(f"\nFound employee ID={row[0]}, Role={row[1]}")
    print(f"Current auth_hash: {row[2][:30]}...")
else:
    print(f"\n❌ Employee not found with email_hash: {email_hash[:30]}...")
    # Try to find cashier by role
    cursor.execute(
        "SELECT id, email_encrypted, email_hash FROM pronto_employees WHERE role = 'cashier' LIMIT 1"
    )
    row = cursor.fetchone()
    if row:
        print(f"\nFound cashier by role: ID={row[0]}, Email={row[1]}")
        print(f"  Email hash in DB: {row[2][:30]}...")
        print(f"  Expected hash:    {email_hash[:30]}...")
        sys.exit(1)
    else:
        print("❌ No cashier found in database")
        sys.exit(1)

# Update
cursor.execute(
    "UPDATE pronto_employees SET auth_hash = %s, allow_scopes = %s WHERE email_hash = %s",
    (auth_hash, '["cashier"]', email_hash),
)
print(f"\nRows affected: {cursor.rowcount}")

# Verify
cursor.execute(
    "SELECT id, role, auth_hash FROM pronto_employees WHERE email_hash = %s", (email_hash,)
)
row = cursor.fetchone()
if row:
    print(f"\nUpdated: ID={row[0]}, Role={row[1]}")
    if row[2] == auth_hash:
        print("✅ Password verified!")
    else:
        print(f"❌ Mismatch! Stored: {row[2][:30]}..., Expected: {auth_hash[:30]}...")
else:
    print("❌ Employee not found!")

cursor.close()
conn.close()
print("\n✅ Done")
