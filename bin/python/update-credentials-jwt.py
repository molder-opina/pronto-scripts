#!/usr/bin/env python3
"""
Script consolidado para actualizar empleados y clientes con credenciales JWT correctas.

Este script:
1. Actualiza todos los empleados existentes con hashes correctos
2. Configura allow_scopes apropiadamente para JWT
3. Actualiza clientes con hashes correctos
4. Verifica que las credenciales funcionen

Uso:
    python bin/python/update-credentials-jwt.py
"""

import os
import sys

# Add project to path for shared imports
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(project_root, "build"))


# Load environment variables from config files
def load_env_file(filepath):
    """Load environment variables from a file."""
    if not os.path.exists(filepath):
        return
    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip())


# Load secrets first (required for hash_identifier and hash_credentials)
load_env_file(os.path.join(project_root, "config", "secrets.env"))
load_env_file(os.path.join(project_root, "config", "general.env"))

try:
    import psycopg2
except ImportError:
    print("❌ Error: El paquete 'psycopg2-binary' no está instalado")
    print("   Para instalar: pip install psycopg2-binary")
    sys.exit(1)

try:
    from shared.security import hash_credentials, hash_identifier
except ImportError:
    print("❌ Error: No se puede importar shared.security")
    print("   Asegúrate de que el directorio src/shared existe")
    sys.exit(1)

print("╔═══════════════════════════════════════════════════════════╗")
print("║                                                           ║")
print("║   🔐 ACTUALIZACIÓN DE CREDENCIALES JWT                   ║")
print("║                                                           ║")
print("╚═══════════════════════════════════════════════════════════╝")
print("")

# Load configuration from environment
postgres_host = os.getenv("POSTGRES_HOST", "localhost")
postgres_port = os.getenv("POSTGRES_PORT", "5432")
postgres_user = os.getenv("POSTGRES_USER", "pronto")
postgres_password = os.getenv("POSTGRES_PASSWORD", "pronto123")
postgres_db = os.getenv("POSTGRES_DB", "pronto")

# Default password for test employees
DEFAULT_PASSWORD = os.getenv("SEED_EMPLOYEE_PASSWORD", "ChangeMe!123")

print("📊 Configuración:")
print(f"   Host: {postgres_host}:{postgres_port}")
print(f"   Usuario: {postgres_user}")
print(f"   Base de datos: {postgres_db}")
print(f"   Password por defecto: {DEFAULT_PASSWORD}")
print("")

# Connect to PostgreSQL
print("🔗 Conectando a PostgreSQL...")
try:
    conn = psycopg2.connect(
        host=postgres_host,
        port=postgres_port,
        user=postgres_user,
        password=postgres_password,
        database=postgres_db,
    )
    conn.autocommit = True
    cursor = conn.cursor()
    print("✅ Conectado a PostgreSQL")
except Exception as e:
    print(f"❌ Error al conectar a PostgreSQL: {e}")
    sys.exit(1)

# Define test employees with correct JWT scopes
print("")
print("👥 Actualizando empleados...")

employees = [
    {
        "email": "admin@cafeteria.test",
        "role": "super_admin",
        "name": "Administrador",
        "allow_scopes": '["admin", "waiter", "chef", "cashier"]',
    },
    {
        "email": "admin-roles@cafeteria.test",
        "role": "admin_roles",
        "name": "Admin Roles",
        "allow_scopes": '["admin", "waiter", "chef", "cashier"]',
    },
    {
        "email": "carlos.chef@cafeteria.test",
        "role": "chef",
        "name": "Carlos Chef",
        "allow_scopes": '["chef"]',
    },
    {
        "email": "juan.mesero@cafeteria.test",
        "role": "waiter",
        "name": "Juan Mesero",
        "allow_scopes": '["waiter", "cashier"]',  # Waiters can also cashier
    },
    {
        "email": "laura.cajera@cafeteria.test",
        "role": "cashier",
        "name": "Laura Cajera",
        "allow_scopes": '["cashier"]',
    },
]

updated_count = 0
created_count = 0

for emp in employees:
    email = emp["email"]
    email_hash = hash_identifier(email)
    auth_hash = hash_credentials(email, DEFAULT_PASSWORD)
    allow_scopes = emp.get("allow_scopes", "[]")

    # Check if employee exists
    cursor.execute("SELECT id, role FROM pronto_employees WHERE email_hash = %s", (email_hash,))
    existing = cursor.fetchone()

    if existing:
        # Update existing employee
        cursor.execute(
            """
            UPDATE pronto_employees
            SET auth_hash = %s,
                role = %s,
                is_active = true,
                name_encrypted = %s,
                email_encrypted = %s,
                allow_scopes = %s
            WHERE email_hash = %s
            """,
            (auth_hash, emp["role"], emp["name"], email, allow_scopes, email_hash),
        )
        print(f"   ✓ Actualizado: {emp['name']} ({emp['role']}) - ID {existing[0]}")
        updated_count += 1
    else:
        # Create new employee
        cursor.execute(
            """
            INSERT INTO pronto_employees
                (email_hash, auth_hash, role, is_active, name_encrypted, email_encrypted, phone_encrypted, preferences, allow_scopes)
                VALUES (%s, %s, %s, true, %s, %s, %s, %s, %s)
            """,
            (
                email_hash,
                auth_hash,
                emp["role"],
                emp["name"],
                email,
                "",  # phone_encrypted
                "",  # preferences
                allow_scopes,
            ),
        )
        print(f"   + Creado: {emp['name']} ({emp['role']})")
        created_count += 1

print(f"\n   📊 Resumen: {updated_count} actualizados, {created_count} creados")

# Update customers with correct hashes
print("")
print("👤 Actualizando clientes...")

# Get all customers
cursor.execute(
    "SELECT id, email_encrypted FROM pronto_customers WHERE email_encrypted IS NOT NULL AND email_encrypted != ''"
)
customers = cursor.fetchall()

customer_updated = 0
for customer_id, email in customers:
    if email:
        # Recalculate email_hash with correct function
        email_hash = hash_identifier(email)
        cursor.execute(
            "UPDATE pronto_customers SET email_hash = %s WHERE id = %s", (email_hash, customer_id)
        )
        customer_updated += 1

print(f"   ✓ {customer_updated} clientes actualizados")

# Verify employees
print("")
print("📊 Verificando empleados...")
cursor.execute(
    """
    SELECT id, email_encrypted, role, allow_scopes, is_active
    FROM pronto_employees
    WHERE role IN ('super_admin', 'admin_roles', 'waiter', 'chef', 'cashier')
    ORDER BY id
    """
)

employees_result = cursor.fetchall()
print(f"✅ {len(employees_result)} empleados en la base de datos:")
for emp_id, email, role, scopes, active in employees_result:
    # Verify scope parsing
    try:
        import json

        scopes_list = json.loads(scopes) if scopes else []
        scopes_str = ", ".join(scopes_list)
    except Exception:
        scopes_str = f"ERROR parsing: {scopes}"

    status = "✓" if active else "✗"
    print(f"   {status} ID {emp_id}: {role:15} - {email:30} - scopes: [{scopes_str}]")

# Test login for each employee
print("")
print("🔐 Verificando autenticación...")
test_results = []

for emp in employees:
    email = emp["email"]
    email_hash = hash_identifier(email)
    test_auth_hash = hash_credentials(email, DEFAULT_PASSWORD)

    cursor.execute(
        "SELECT id, role, auth_hash FROM pronto_employees WHERE email_hash = %s", (email_hash,)
    )
    row = cursor.fetchone()

    if row:
        emp_id, role, stored_hash = row
        matches = stored_hash == test_auth_hash
        test_results.append({"email": email, "role": role, "matches": matches})

        if matches:
            print(f"   ✅ {email:30} - Auth OK")
        else:
            print(f"   ❌ {email:30} - Auth FAILED")
            print(f"      Stored:   {stored_hash[:50]}...")
            print(f"      Expected: {test_auth_hash[:50]}...")
    else:
        print(f"   ❌ {email:30} - NOT FOUND")
        test_results.append({"email": email, "role": emp["role"], "matches": False})

# Close connection
cursor.close()
conn.close()

print("")
print("╔═══════════════════════════════════════════════════════════╗")
print("║                                                           ║")
print("║   ✅ ACTUALIZACIÓN COMPLETADA                            ║")
print("║                                                           ║")
print("╚═══════════════════════════════════════════════════════════╝")
print("")

# Summary
all_passed = all(r["matches"] for r in test_results)
if all_passed:
    print("✅ Todas las credenciales verificadas correctamente")
else:
    print("⚠️  Algunas credenciales tienen problemas")

print("")
print("🔑 Credenciales de prueba:")
print(f"   Password: {DEFAULT_PASSWORD}")
print("")
for emp in employees:
    print(f"   📧 {emp['role']:15} - {emp['email']}")
print("")
