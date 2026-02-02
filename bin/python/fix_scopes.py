#!/usr/bin/env python3
"""
Fix employee scopes after bcrypt migration.

This script corrects the allow_scopes column for all employees.
"""

import logging
import os
import sys
from pathlib import Path

# Add pronto-libs to path
REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "pronto-libs/src"))

from pronto_shared.db import get_session, init_engine
from pronto_shared.config import load_config
from sqlalchemy import text

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)


def fix_scopes():
    """Fix employee scopes in database."""
    logger.info("Fixing employee scopes...")

    # Initialize database engine
    config = load_config("migrate_to_bcrypt")
    init_engine(config)

    with get_session() as db:
        # Update waiters to have only waiter scope
        result = db.execute(
            text("""
                UPDATE pronto_employees
                SET allow_scopes = '["waiter"]'
                WHERE role = 'waiter'
            """)
        )
        logger.info(f"✓ Updated {result.rowcount} waiters")

        # Update cashiers to have only cashier scope
        result = db.execute(
            text("""
                UPDATE pronto_employees
                SET allow_scopes = '["cashier"]'
                WHERE role = 'cashier'
            """)
        )
        logger.info(f"✓ Updated {result.rowcount} cashiers")

        # Update chefs to have only chef scope
        result = db.execute(
            text("""
                UPDATE pronto_employees
                SET allow_scopes = '["chef"]'
                WHERE role = 'chef'
            """)
        )
        logger.info(f"✓ Updated {result.rowcount} chefs")

        # Update system to have only system scope
        result = db.execute(
            text("""
                UPDATE pronto_employees
                SET allow_scopes = '["system", "admin"]'
                WHERE role = 'system'
            """)
        )
        logger.info(f"✓ Updated {result.rowcount} system users")

        # Update admins to have only admin scope
        result = db.execute(
            text("""
                UPDATE pronto_employees
                SET allow_scopes = '["admin"]'
                WHERE role = 'admin'
            """)
        )
        logger.info(f"✓ Updated {result.rowcount} admins")

        # Verify the changes
        result = db.execute(
            text("""
                SELECT role, allow_scopes, COUNT(*) as count
                FROM pronto_employees
                GROUP BY role, allow_scopes
                ORDER BY role
            """)
        ).fetchall()

        logger.info("\n📊 Employee Scopes After Fix:")
        logger.info("-" * 60)
        for role, scopes, count in result:
            logger.info("  {:10} | Scopes: {} | Count: {}".format(role, scopes, count))
        logger.info("-" * 60)


if __name__ == "__main__":
    try:
        fix_scopes()
        logger.info("\n✅ Scopes fixed successfully!")
    except Exception as e:
        logger.error(f"Fix failed: {e}", exc_info=True)
        sys.exit(1)
