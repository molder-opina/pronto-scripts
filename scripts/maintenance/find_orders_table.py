#!/usr/bin/env python3
"""Find the correct orders table for Pronto system"""

import os

import psycopg2
from dotenv import load_dotenv

load_dotenv(".env")


def find_orders():
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

        # Find tables with foreign keys to dining_sessions
        cursor.execute(
            """
            SELECT DISTINCT
                tc.table_name,
                kcu.column_name
            FROM information_schema.table_constraints AS tc
            JOIN information_schema.key_column_usage AS kcu
                ON tc.constraint_name = kcu.constraint_name
            JOIN information_schema.constraint_column_usage AS ccu
                ON ccu.constraint_name = tc.constraint_name
            WHERE tc.constraint_type = 'FOREIGN KEY'
            AND ccu.table_name = 'dining_sessions'
            AND tc.table_schema = 'public';
        """
        )

        print("\n📋 Tables referencing dining_sessions:")
        tables_with_session_id = []
        for row in cursor.fetchall():
            print(f"  {row[0]}: {row[1]}")
            tables_with_session_id.append(row[0])

        # Check if any of these tables might be the orders table
        for table in tables_with_session_id:
            if "order" in table.lower():
                print(f"\n📋 {table} columns:")
                cursor.execute(
                    f"""
                    SELECT column_name, data_type
                    FROM information_schema.columns
                    WHERE table_schema = 'public'
                    AND table_name = '{table}'
                    ORDER BY ordinal_position
                """
                )
                for row in cursor.fetchall():
                    print(f"  {row[0]:30} {row[1]}")

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"❌ Error: {e}")


if __name__ == "__main__":
    find_orders()
