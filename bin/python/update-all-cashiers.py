#!/usr/bin/env python3
"""Update all cashier passwords using shared.security."""

import os
import sys

# Add project to path for shared imports
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Ensure pronto_shared is importable
try:
    import pronto_shared
except ImportError:
    raise ImportError("pronto_shared package not found. Install it from pronto-libs repo:
    cd ../pronto-libs && pip install -e .")


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

# Test emails to try
test_emails = [
    ("laura.cajera@cafeteria.test", "Laura Cajera"),
    ("roberto.cajero@cafeteria.test", "Roberto Cajero"),
]

default_password = os.getenv("SEED_EMPLOYEE_PASSWORD", "ChangeMe!123")

print(f"Using password: {default_password}\n")

for email, name in test_emails:
    email_hash = hash_identifier(email)
    auth_hash = hash_credentials(email, default_password)

    cursor.execute("SELECT id FROM pronto_employees WHERE email_hash = %s", (email_hash,))
    row = cursor.fetchone()

    if row:
        cashier_id = row[0]
        cursor.execute(
            "UPDATE pronto_employees SET auth_hash = %s, allow_scopes = %s WHERE id = %s",
            (auth_hash, '["cashier"]', cashier_id),
        )
        print(f"✓ ID {cashier_id}: Updated {name} ({email})")
        print(f"  Email hash: {email_hash[:30]}...")
        print(f"  Auth hash: {auth_hash[:30]}...")

        # Verify
        cursor.execute("SELECT auth_hash FROM pronto_employees WHERE id = %s", (cashier_id,))
        stored = cursor.fetchone()[0]
        if stored == auth_hash:
            print(f"  ✅ Verified!")
        else:
            print(f"  ❌ Verification failed!")
    else:
        print(f"✗ {name} ({email}) not found in DB")
        print(f"  Expected email_hash: {email_hash[:30]}...")

# Show all cashiers
cursor.execute(
    "SELECT id, email_encrypted, auth_hash IS NOT NULL as has_password FROM pronto_employees WHERE role = 'cashier'"
)
rows = cursor.fetchall()
if rows:
    print(f"\n=== All cashiers in database ===")
    for cashier_id, email, has_password in rows:
        print(f"  ID {cashier_id}: {email} - Has password: {has_password}")

cursor.close()
conn.close()
print("\n✅ Done")
