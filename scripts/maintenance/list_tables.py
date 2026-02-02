#!/usr/bin/env python3
"""List all tables in Supabase database"""

import os

import psycopg2
from dotenv import load_dotenv

load_dotenv(".env")


def list_tables():
    db_config = {
        "host": os.getenv("SUPABASE_DB_HOST"),
        "port": os.getenv("SUPABASE_DB_PORT"),
        "user": os.getenv("SUPABASE_DB_USER"),
        "password": os.getenv("SUPABASE_DB_PASSWORD"),
        "database": os.getenv("SUPABASE_DB_NAME"),
        "sslmode": os.getenv("SUPABASE_DB_SSLMODE", "require"),
    }

    try:
        conn = psycopg2.connect(**db_config)
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT table_schema, table_name
            FROM information_schema.tables
            WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
            AND table_type = 'BASE TABLE'
            ORDER BY table_schema, table_name
        """
        )

        print("\n📋 Tables in database:")
        print("-" * 60)
        for row in cursor.fetchall():
            print(f"  {row[0]}.{row[1]}")

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"❌ Error: {e}")


if __name__ == "__main__":
    list_tables()
