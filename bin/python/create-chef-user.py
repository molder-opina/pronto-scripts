#!/usr/bin/env python3
"""
Create missing chef user for testing.
"""

import hashlib
import os
import sys

# Add project to path - must include src/ for shared imports
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Ensure pronto_shared is importable
try:
    import pronto_shared
except ImportError:
    raise ImportError("pronto_shared package not found. Install it from pronto-libs repo:
    cd ../pronto-libs && pip install -e .")

from pronto_shared.security import hash_credentials


def create_chef_user():
    """Create the missing chef user."""
    email = "carlos.chef@cafeteria.test"
    password = "ChangeMe!123"  # Default password from test data

    # Generate hashes
    email_hash = hashlib.sha256(email.encode()).hexdigest()
    auth_hash = hash_credentials(email, password)

    print(f"Chef User Details:")
    print(f"  Email: {email}")
    print(f"  Email hash: {email_hash}")
    print(f"  Auth hash: {auth_hash[:50]}...")
    print(f"  Role: chef")
    print(f"  Scopes: ['chef']")

    # Insert into database using raw SQL
    import psycopg2
    from dotenv import load_dotenv

    load_dotenv(os.path.join(project_root, ".env"))

    conn = psycopg2.connect(
        host=os.getenv("POSTGRES_HOST", "localhost"),
        port=os.getenv("POSTGRES_PORT", "5432"),
        database=os.getenv("POSTGRES_DB", "pronto"),
        user=os.getenv("POSTGRES_USER", "pronto"),
        password=os.getenv("POSTGRES_PASSWORD", "pronto123"),
    )

    cursor = conn.cursor()

    # Check if chef exists
    cursor.execute("SELECT id FROM pronto_employees WHERE role = 'chef'")
    existing = cursor.fetchone()

    if existing:
        print(f"\n⚠️  Chef user already exists (id={existing[0]})")
        # Update auth_hash
        cursor.execute(
            """
            UPDATE pronto_employees
            SET auth_hash = %s, email_hash = %s, is_active = true
            WHERE role = 'chef'
            """,
            (auth_hash, email_hash),
        )
        print("✓ Updated existing chef user with auth_hash")
    else:
        cursor.execute(
            """
            INSERT INTO pronto_employees
                (email_hash, auth_hash, role, is_active, name_encrypted, email_encrypted, allow_scopes)
            VALUES (%s, %s, 'chef', true, 'Carlos Chef', %s, '["chef"]')
            """,
            (email_hash, auth_hash, email),
        )
        print(f"\n✓ Created new chef user")

    conn.commit()
    cursor.close()
    conn.close()

    print("\n✅ Chef user ready for testing!")
    print(f"   Login: {email}")
    print(f"   Password: {password}")


if __name__ == "__main__":
    create_chef_user()
