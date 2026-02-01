#!/usr/bin/env python3
"""Apply migration to Supabase database."""
from __future__ import annotations

import os
import sys
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

# Load environment variables
load_dotenv("config/general.env")
load_dotenv("config/secrets.env")


def apply_migration(migration_file: str) -> None:
    """Apply a SQL migration file to Supabase."""
    # Get database credentials from environment
    db_config = {
        "host": os.getenv("SUPABASE_DB_HOST"),
        "port": os.getenv("SUPABASE_DB_PORT"),
        "user": os.getenv("SUPABASE_DB_USER"),
        "password": os.getenv("SUPABASE_DB_PASSWORD"),
        "database": os.getenv("SUPABASE_DB_NAME"),
        "sslmode": os.getenv("SUPABASE_DB_SSLMODE", "require"),
    }

    # Read migration file
    migration_sql = Path(migration_file).read_text()

    print(f"🔄 Applying migration: {migration_file}")
    print(f"📍 Database: {db_config['host']}")

    try:
        # Connect to database
        conn = psycopg2.connect(**db_config)
        cursor = conn.cursor()

        # Execute migration
        cursor.execute(migration_sql)
        conn.commit()

        print("✅ Migration applied successfully!")

        # Verify the column exists
        cursor.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name = 'orders'
            AND column_name = 'workflow_status'
        """
        )
        result = cursor.fetchone()

        if result:
            print("✅ Verified: Column 'workflow_status' exists in orders table")
        else:
            print("⚠️  Warning: Could not verify column existence")

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"❌ Error applying migration: {e}")
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 apply_supabase_migration.py <migration_file.sql>")
        sys.exit(1)

    migration_file = sys.argv[1]

    if not Path(migration_file).exists():
        print(f"❌ Error: Migration file not found: {migration_file}")
        sys.exit(1)

    apply_migration(migration_file)
