#!/usr/bin/env python3
"""Check employees in database."""

import os

import psycopg2

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

cursor.execute("SELECT id, email_hash, role, allow_scopes FROM pronto_employees")
for row in cursor.fetchall():
    print(f"ID: {row[0]}, Email: {row[1]}, Role: {row[2]}, Scopes: {row[3]}")

cursor.close()
conn.close()
