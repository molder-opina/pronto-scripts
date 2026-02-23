import sys
import os
import psycopg2
# Ensure pronto_shared is importable
try:
    import pronto_shared
    from pronto_shared.security import hash_credentials, hash_identifier
except ImportError:
    print("Should run inside container with pronto_shared installed")
    sys.exit(1)

# Config - Use env vars from container or defaults
POSTGRES_HOST = os.getenv("POSTGRES_HOST", "postgres")
POSTGRES_USER = os.getenv("POSTGRES_USER", "pronto")
POSTGRES_PASS = os.getenv("POSTGRES_PASSWORD", "pronto123")
POSTGRES_DB = os.getenv("POSTGRES_DB", "pronto")

# Target
EMAIL = "admin@cafeteria.test"
PASSWORD = "ChangeMe!123"

def reset():
    print(f"Resetting password for {EMAIL}...")
    try:
        conn = psycopg2.connect(
            host=POSTGRES_HOST,
            user=POSTGRES_USER,
            password=POSTGRES_PASS,
            database=POSTGRES_DB
        )
        conn.autocommit = True
        cursor = conn.cursor()

        email_hash = hash_identifier(EMAIL)
        auth_hash = hash_credentials(EMAIL, PASSWORD)
        
        # Check if exists
        cursor.execute("SELECT id FROM pronto_employees WHERE email_hash = %s", (email_hash,))
        res = cursor.fetchone()
        
        if res:
             print(f"User found (ID: {res[0]}). Updating...")
             cursor.execute(
                 "UPDATE pronto_employees SET auth_hash = %s, is_active = true WHERE email_hash = %s",
                 (auth_hash, email_hash)
             )
             print("Password updated.")
        else:
             print(f"User {EMAIL} not found via hash. Creating...")
             # Insert with required fields
             cursor.execute(
                 """
                 INSERT INTO pronto_employees 
                 (employee_code, first_name, last_name, role, is_active, 
                  auth_hash, email_hash, email_encrypted, name_encrypted)
                 VALUES (%s, %s, %s, %s, true, %s, %s, %s, %s)
                 """,
                 (
                     "ADMIN_TEST", "Admin", "Test", "admin", 
                     auth_hash, email_hash, "encrypted_email_placeholder", "encrypted_name_placeholder"
                 )
             )
             print("User created.")

        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    reset()
