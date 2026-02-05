#!/usr/bin/env python3
"""
Script para corregir empleados de prueba en PostgreSQL.
Este script:
1. Verifica si existen los empleados de prueba por email
2. Si no existen, los crea
3. Si existen, los actualiza con los datos correctos
4. Usa hash_identifier y hash_credentials de pronto_shared.security

Empleados a crear/actualizar:
- system (admin@cafeteria.test)
- admin (admin-roles@cafeteria.test)
- chef (carlos.chef@cafeteria.test)
- waiter (juan.mesero@cafeteria.test)
- cashier (laura.cajera@cafeteria.test)
"""

import os
import sys

# Add project to path for shared imports
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Ensure pronto_shared is importable
try:
    import pronto_shared
except ImportError:
    raise ImportError(
        "pronto_shared package not found. Install it from pronto-libs repo:\n"
        "cd ../pronto-libs && pip install -e ."
    )

try:
    import psycopg2
except ImportError:
    print("❌ Error: El paquete 'psycopg2-binary' no está instalado")
    print("   Para instalar: pip install psycopg2-binary")
    sys.exit(1)

try:
    from pronto_shared.security import hash_credentials, hash_identifier
except ImportError:
    print("❌ Error: No se puede importar pronto_shared.security")
    print("   Asegúrate de que exista pronto-libs/src/pronto_shared")
    sys.exit(1)

print("╔═════════════════════════════════════════════════╗")
print("║                                                       ║")
print("║   🛠️  CORRECCIÓN DE EMPLEADOS DE PRUEBA          ║")
print("║                                                       ║")
print("╚═════════════════════════════════════════════════╝")
print("")

# Load configuration from environment
postgres_host = os.getenv("POSTGRES_HOST", "localhost")
postgres_port = os.getenv("POSTGRES_PORT", "5432")
postgres_user = os.getenv("POSTGRES_USER", "pronto")
postgres_password = os.getenv("POSTGRES_PASSWORD", "pronto123")
postgres_db = os.getenv("POSTGRES_DB", "pronto")

print("📊 Configuración:")
print(f"   Host: {postgres_host}:{postgres_port}")
print(f"   Usuario: {postgres_user}")
print(f"   Base de datos: {postgres_db}")
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

# Define test employees
test_employees = [
    {
        "email_encrypted": "admin@cafeteria.test",
        "role": "system",
        "name": "Administrador",
        "phone": "",
        "is_active": True,
        "name_encrypted": "Administrador",
        "phone_encrypted": "",
        "allow_scopes": '["system", "admin", "waiter", "chef", "cashier"]',
    },
    {
        "email_encrypted": "admin-roles@cafeteria.test",
        "role": "admin",
        "name": "Admin Roles",
        "phone": "",
        "is_active": True,
        "name_encrypted": "Admin Roles",
        "phone_encrypted": "",
        "allow_scopes": '["admin", "waiter", "chef", "cashier"]',
    },
    {
        "email_encrypted": "carlos.chef@cafeteria.test",
        "role": "chef",
        "name": "Carlos Chef",
        "phone": "",
        "is_active": True,
        "name_encrypted": "Carlos Chef",
        "phone_encrypted": "",
        "allow_scopes": '["chef"]',
    },
    {
        "email_encrypted": "juan.mesero@cafeteria.test",
        "role": "waiter",
        "name": "Juan Mesero",
        "phone": "",
        "is_active": True,
        "name_encrypted": "Juan Mesero",
        "phone_encrypted": "",
        "allow_scopes": '["waiter"]',
    },
    {
        "email_encrypted": "laura.cajera@cafeteria.test",
        "role": "cashier",
        "name": "Laura Cajera",
        "phone": "",
        "is_active": True,
        "name_encrypted": "Laura Cajera",
        "phone_encrypted": "",
        "allow_scopes": '["cashier"]',
    },
]

print("")
print("👥 Procesando empleados de prueba...")

for emp in test_employees:
    email = emp["email_encrypted"]
    email_hash = hash_identifier(email)
    auth_hash = hash_credentials(email, "ChangeMe!123")
    allow_scopes = emp.get("allow_scopes", "[]")

    # Check if employee exists by email_hash
    cursor.execute(
        "SELECT id, allow_scopes FROM pronto_employees WHERE email_hash = %s", (email_hash,)
    )
    existing = cursor.fetchone()

    if existing:
        emp_id, existing_scopes = existing
        # Update existing employee
        cursor.execute(
            """
            UPDATE pronto_employees
            SET auth_hash = %s,
                role = %s,
                is_active = true,
                name_encrypted = %s,
                email_encrypted = %s,
                phone_encrypted = %s,
                allow_scopes = %s
            WHERE email_hash = %s
            """,
            (
                auth_hash,
                emp["role"],
                emp["name_encrypted"],
                email,
                emp["phone_encrypted"],
                allow_scopes,
                email_hash,
            ),
        )
        print(f"   ✓ Actualizado: {emp['name']} ({emp['role']}) - ID {emp_id}")
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
                emp["name_encrypted"],
                email,
                emp["phone_encrypted"],
                "",
                allow_scopes,
            ),
        )
        print(f"   + Creado: {emp['name']} ({emp['role']})")

print("")
print("   ✓ " + str(len(test_employees)) + " empleados de prueba procesados")

# Verify final result
print("")
print("📊 Verificando empleados finales...")
cursor.execute(
    """
    SELECT id, email_encrypted, role, allow_scopes, is_active
    FROM pronto_employees
    WHERE role IN ('system', 'admin', 'waiter', 'chef', 'cashier')
    ORDER BY id
    """
)

employees = cursor.fetchall()
print("✅ " + str(len(employees)) + " empleados de prueba:")
for emp in employees:
    emp_id, email, role, scopes, active = emp
    # Verify scope parsing
    try:
        import json

        scopes_list = json.loads(scopes) if scopes else []
        scopes_str = ", ".join(scopes_list)
    except Exception:
        scopes_str = f"ERROR parsing: {scopes}"

    print(f"   ID {emp_id}: {role} - scopes: {scopes_str} - activo: {active}")

# Close connection
cursor.close()
conn.close()

print("")
print("╔═════════════════════════════════════════════════╗")
print("║                                                       ║")
print("║   ✅ EMPLEADOS CORREGIDOS                             ║")
print("║                                                       ║")
print("╚═══════════════════════════════════════════════╝")
print("")
print("🚀 Para probar el sistema, usa estas credenciales:")
print("")
print("   📧 ADMIN (todos los scopes):")
print("      Email: admin@cafeteria.test / admin-roles@cafeteria.test")
print("      Password: ChangeMe!123")
print("")
print("   👨 CHEF (cocina):")
print("      Email: carlos.chef@cafeteria.test")
print("      Password: ChangeMe!123")
print("")
print("   🧔 MESERO (mesas, pedidos, cobro):")
print("      Email: juan.mesero@cafeteria.test")
print("      Password: ChangeMe!123")
print("")
print("   💰 CAJERO (cobro, envíos de ticket):")
print("      Email: laura.cajera@cafeteria.test")
print("      Password: ChangeMe!123")
print("")
