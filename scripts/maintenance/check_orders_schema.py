#!/usr/bin/env python3
"""Check orders table schema in Supabase"""

import os

import psycopg2
from dotenv import load_dotenv

# Load environment variables
load_dotenv(".env")


def check_schema():
    """Check orders table schema"""
    db_config = {
        "host": os.getenv("SUPABASE_DB_HOST"),
        "port": os.getenv("SUPABASE_DB_PORT"),
        "user": os.getenv("SUPABASE_DB_USER"),
        "password": os.getenv("SUPABASE_DB_PASSWORD"),
        "database": os.getenv("SUPABASE_DB_NAME"),
        "sslmode": os.getenv("SUPABASE_DB_SSLMODE", "require"),
    }

    print(f"📍 Connecting to: {db_config['host']}")

    try:
        conn = psycopg2.connect(**db_config)
        cursor = conn.cursor()

        # Get all columns from orders table
        cursor.execute(
            """
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'orders'
            ORDER BY ordinal_position
        """
        )

        print("\n📋 Orders table columns:")
        print("-" * 80)
        for row in cursor.fetchall():
            print(f"  {row[0]:30} {row[1]:20} NULL: {row[2]:5} DEFAULT: {row[3]}")

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"❌ Error: {e}")


if __name__ == "__main__":
    check_schema()
