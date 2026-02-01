#!/usr/bin/env python3
"""Check dining_sessions table schema"""
import os

import psycopg2
from dotenv import load_dotenv

load_dotenv("config/general.env")
load_dotenv("config/secrets.env")


def check_schema():
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

        # Check dining_sessions table
        cursor.execute(
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'dining_sessions'
            ORDER BY ordinal_position
        """
        )

        print("\n📋 dining_sessions table columns:")
        for row in cursor.fetchall():
            print(f"  {row[0]:30} {row[1]}")

        # Now check if there's a relationship to orders
        cursor.execute(
            """
            SELECT
                tc.constraint_name,
                kcu.column_name,
                ccu.table_name AS foreign_table_name,
                ccu.column_name AS foreign_column_name
            FROM information_schema.table_constraints AS tc
            JOIN information_schema.key_column_usage AS kcu
                ON tc.constraint_name = kcu.constraint_name
                AND tc.table_schema = kcu.table_schema
            JOIN information_schema.constraint_column_usage AS ccu
                ON ccu.constraint_name = tc.constraint_name
            WHERE tc.constraint_type = 'FOREIGN KEY'
            AND tc.table_name='dining_sessions';
        """
        )

        print("\n📋 Foreign keys from dining_sessions:")
        for row in cursor.fetchall():
            print(f"  {row[1]} -> {row[2]}.{row[3]}")

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"❌ Error: {e}")


if __name__ == "__main__":
    check_schema()
