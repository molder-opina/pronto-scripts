#!/bin/bash

# Script para aplicar implementación de reautenticación super_admin
# Uso: bash scripts/apply_reauth_implementation.sh

set -e  # Exit on error

echo "========================================"
echo "Aplicando implementación de reauth"
echo "========================================"
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -f "IMPLEMENTACION_REAUTH.md" ]; then
    echo "❌ Error: Debe ejecutar este script desde la raíz del proyecto"
    exit 1
fi

# 1. Verificar Python 3.10+
echo "1. Verificando versión de Python..."
python_version=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
required_version="3.10"

if [ "$(printf '%s\n' "$required_version" "$python_version" | sort -V | head -n1)" != "$required_version" ]; then
    echo "❌ Error: Se requiere Python 3.10 o superior (actual: $python_version)"
    exit 1
fi
echo "✅ Python $python_version OK"
echo ""

# 2. Instalar dependencias
echo "2. Instalando dependencias..."
if [ -f ".venv/bin/activate" ]; then
    source .venv/bin/activate
    cd src/employees_app
    pip install -q -r requirements.txt
    if [ $? -eq 0 ]; then
        echo "✅ Dependencias instaladas"
    else
        echo "❌ Error instalando dependencias"
        exit 1
    fi
    cd ../..
elif [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    cd src/employees_app
    pip install -q -r requirements.txt
    if [ $? -eq 0 ]; then
        echo "✅ Dependencias instaladas"
    else
        echo "❌ Error instalando dependencias"
        exit 1
    fi
    cd ../..
else
    echo "⚠️  No se encontró virtualenv, intentando pip global..."
    cd src/employees_app
    python3 -m pip install -q -r requirements.txt 2>/dev/null || echo "⚠️  Instalación saltada (requiere virtualenv)"
    cd ../..
fi
echo ""

# 3. Verificar HANDOFF_PEPPER
echo "3. Verificando HANDOFF_PEPPER..."
if grep -q "^HANDOFF_PEPPER=" config/secrets.env; then
    pepper_value=$(grep "^HANDOFF_PEPPER=" config/secrets.env | cut -d'=' -f2)
    if [ "$pepper_value" = "your-random-pepper-here-32chars-minimum" ] || [ -z "$pepper_value" ]; then
        echo "⚠️  HANDOFF_PEPPER tiene valor por defecto, generando uno nuevo..."
        new_pepper=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
        sed -i.bak "s/^HANDOFF_PEPPER=.*/HANDOFF_PEPPER=$new_pepper/" config/secrets.env
        echo "✅ Nuevo HANDOFF_PEPPER generado"
    else
        echo "✅ HANDOFF_PEPPER configurado"
    fi
else
    echo "❌ Error: HANDOFF_PEPPER no encontrado en config/secrets.env"
    exit 1
fi
echo ""

# 4. Verificar SECRET_KEY
echo "4. Verificando SECRET_KEY..."
if grep -q "^SECRET_KEY=change-me-please" config/secrets.env; then
    echo "⚠️  SECRET_KEY tiene valor por defecto, generando uno nuevo..."
    new_secret=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    sed -i.bak "s/^SECRET_KEY=.*/SECRET_KEY=$new_secret/" config/secrets.env
    echo "✅ Nuevo SECRET_KEY generado"
else
    echo "✅ SECRET_KEY configurado"
fi
echo ""

# 5. Test de imports
echo "5. Verificando imports..."
python3 << 'PYEOF'
try:
    from build.employees_app.extensions import csrf
    from shared.datetime_utils import utcnow
    from shared.models import SuperAdminHandoffToken, AuditLog
    print("✅ Todos los imports funcionan correctamente")
except ImportError as e:
    print(f"❌ Error en imports: {e}")
    exit(1)
PYEOF

if [ $? -ne 0 ]; then
    exit 1
fi
echo ""

# 6. Verificar migración de base de datos
echo "6. Verificando migración de base de datos..."
if [ -f "src/shared/migrations/010_add_super_admin_handoff_and_audit.sql" ]; then
    echo "✅ Archivo de migración existe"

    # Check if tables exist in database
    source config/general.env 2>/dev/null
    source config/secrets.env 2>/dev/null

    if command -v psql &> /dev/null && [ ! -z "${SUPABASE_DB_HOST:-}" ]; then
        echo "   Verificando si las tablas ya existen..."
        export PGPASSWORD="${SUPABASE_DB_PASSWORD}"
        table_exists=$(psql -h "$SUPABASE_DB_HOST" -p "${SUPABASE_DB_PORT:-6543}" -U "$SUPABASE_DB_USER" -d "${SUPABASE_DB_NAME:-postgres}" -tAc "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='super_admin_handoff_tokens')" 2>/dev/null || echo "f")
        unset PGPASSWORD

        if [ "$table_exists" = "t" ]; then
            echo "✅ Migración ya aplicada (tablas existen)"
        else
            echo "⚠️  Migración NO aplicada aún"
            echo ""
            echo "Para aplicar la migración ejecuta:"
            echo "  bash bin/apply_migration.sh src/shared/migrations/010_add_super_admin_handoff_and_audit.sql"
        fi
    else
        echo "   (psql no disponible o DB no configurada, saltando verificación)"
    fi
else
    echo "❌ Error: Archivo de migración no encontrado"
    exit 1
fi
echo ""

# 7. Verificar configuración
echo "7. Verificando configuración..."
echo "   ALLOWED_HOSTS: $(grep '^ALLOWED_HOSTS=' config/secrets.env | cut -d'=' -f2)"
echo "   NUM_PROXIES: $(grep '^NUM_PROXIES=' config/secrets.env | cut -d'=' -f2)"
echo "   CORS_ALLOWED_ORIGINS: $(grep '^CORS_ALLOWED_ORIGINS=' config/secrets.env | cut -d'=' -f2 | head -c 50)"
echo ""

# 8. Resumen
echo "========================================"
echo "✅ Implementación base aplicada"
echo "========================================"
echo ""
echo "IMPORTANTE: Archivos que necesitan creación manual:"
echo ""
echo "1. src/employees_app/routes/system/auth.py (CRÍTICO)"
echo "   - Consola /system exclusiva super_admin"
echo "   - Endpoints /system/reauth para handoff"
echo ""
echo "2. Actualizar cada scope auth.py (CRÍTICO):"
echo "   - src/employees_app/routes/waiter/auth.py"
echo "   - src/employees_app/routes/chef/auth.py"
echo "   - src/employees_app/routes/cashier/auth.py"
echo "   - src/employees_app/routes/admin/auth.py"
echo "   Agregar endpoint @csrf.exempt super_admin_login"
echo ""
echo "3. Templates de login y reauth:"
echo "   - login_system.html"
echo "   - system_reauth_confirm.html"
echo "   - system_reauth_redirect.html"
echo ""
echo "4. Actualizar src/employees_app/app.py:"
echo "   - Import csrf desde extensions"
echo "   - CORS con orígenes explícitos"
echo "   - ProxyFix si hay reverse proxy"
echo "   - Headers de seguridad"
echo ""
echo "Ver IMPLEMENTACION_REAUTH.md para detalles completos."
echo ""
echo "Si la migración no está aplicada, siguiente paso:"
echo "  bash bin/apply_migration.sh src/shared/migrations/010_add_super_admin_handoff_and_audit.sql"
echo ""
