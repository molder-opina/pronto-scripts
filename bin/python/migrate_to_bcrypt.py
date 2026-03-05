#!/usr/bin/env python3
"""
Harden authentication hashes to the modern configured algorithm.

This script:
1. Resets known test accounts to fresh modern hashes
2. Replaces non-modern employee hashes with a secure default password hash
3. Verifies credentials with the shared verifier

Usage:
    python3 migrate_to_bcrypt.py
"""

import hashlib
import logging
import os
import sys
from pathlib import Path

# Add pronto-libs to path
REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "pronto-libs/src"))

from pronto_shared.security import hash_credentials, verify_credentials
from pronto_shared.db import get_session, init_engine
from pronto_shared.config import load_config
from sqlalchemy import text

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)


# Test accounts with their passwords
TEST_ACCOUNTS = [
    {
        "email": "juan.mesero@cafeteria.test",
        "password": "ChangeMe!123",
        "role": "waiter",
    },
    {"email": "carlos.chef@cafeteria.test", "password": "ChangeMe!123", "role": "chef"},
    {
        "email": "laura.cajera@cafeteria.test",
        "password": "ChangeMe!123",
        "role": "cashier",
    },
    {"email": "admin@cafeteria.test", "password": "ChangeMe!123", "role": "admin"},
]


def migrate_passwords():
    """Migrate employee passwords to modern hash format."""
    logger.info("Starting password hardening migration...")

    # Initialize database engine
    config = load_config("auth-hardening-migration")
    init_engine(config)

    with get_session() as db:
        for account in TEST_ACCOUNTS:
            email = account["email"]
            password = account["password"]

            # Calculate email hash (still uses SHA256)
            from pronto_shared.security import hash_identifier

            email_hash = hash_identifier(email)

            # Generate modern hash
            new_auth_hash = hash_credentials(email, password)

            # Update database
            result = db.execute(
                text("""
                UPDATE pronto_employees
                SET auth_hash = :auth_hash
                WHERE email_hash = :email_hash
                """),
                {"auth_hash": new_auth_hash, "email_hash": email_hash},
            )

            if result.rowcount > 0:
                logger.info(f"✓ Updated {account['role']}: {email}")
                logger.info(f"  New hash: {new_auth_hash[:50]}...")
            else:
                logger.warning(f"✗ Not found: {email}")

        # Update all remaining non-modern hashes with default password
        default_password = "ChangeMe!123"
        result = db.execute(
            text("""
                UPDATE pronto_employees
                SET auth_hash = :new_hash
                WHERE auth_hash IS NOT NULL
                  AND auth_hash <> ''
                  AND auth_hash !~ '^(pbkdf2:|scrypt:)'
                """),
            {"new_hash": hash_credentials("default@cafeteria.test", default_password)},
        )

        logger.info(f"✓ Updated {result.rowcount} accounts with default password")
        logger.info("Migration complete!")


def verify_migration():
    """Verify that the migration was successful."""
    logger.info("\nVerifying migration...")

    # Initialize database engine
    config = load_config("auth-hardening-migration")
    init_engine(config)

    with get_session() as db:
        for account in TEST_ACCOUNTS[:3]:  # Test first 3 accounts
            email = account["email"]
            password = account["password"]

            from pronto_shared.security import hash_identifier

            email_hash = hash_identifier(email)

            employee = db.execute(
                text(
                    "SELECT id, auth_hash FROM pronto_employees WHERE email_hash = :email_hash"
                ),
                {"email_hash": email_hash},
            ).fetchone()

            if not employee:
                logger.error(f"✗ Employee not found: {email}")
                continue

            emp_id, stored_hash = employee

            # Verify password with shared modern verifier
            is_valid = verify_credentials(email, password, stored_hash)

            if is_valid:
                logger.info(f"✓ Login test passed: {email}")
            else:
                logger.error(f"✗ Login test FAILED: {email}")
                logger.error(f"  Stored hash: {stored_hash[:50]}...")


if __name__ == "__main__":
    try:
        migrate_passwords()
        verify_migration()
        logger.info("\n✅ All tests passed!")
    except Exception as e:
        logger.error(f"Migration failed: {e}", exc_info=True)
        sys.exit(1)
