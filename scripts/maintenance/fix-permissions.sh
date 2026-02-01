#!/bin/bash
# =============================================================================
# Script para corregir permisos de archivos
# =============================================================================

set -e

echo "🔧 Corrigiendo permisos de archivos..."
echo ""

# Archivos que NO deberían ser ejecutables
echo "📝 Removiendo permisos de ejecución de archivos que no lo necesitan..."
chmod -x src/employees_app/services/order_service.py
chmod -x src/employees_app/__init__.py
chmod -x conf/secrets.env
chmod -x src/shared/services/notifications.py
chmod -x src/employees_app/decorators.py
chmod -x src/employees_app/services/__init__.py
chmod -x src/shared/services/seed.py
chmod -x src/employees_app/services/role_service.py
chmod -x src/shared/auth/service.py
chmod -x src/employees_app/services/employee_service.py
chmod -x src/shared/security.py
chmod -x src/shared/logging_config.py
chmod -x RESUMEN_IMPLEMENTACION.md
chmod -x conf/general.env.bak.2025-11-04-192157
chmod -x src/employees_app/static/css/styles.css
chmod -x src/clients_app/services/__init__.py
chmod -x src/shared/constants.py
chmod -x src/clients_app/services/menu_service.py
chmod -x src/shared/serializers.py
chmod -x src/shared/security_middleware.py
chmod -x src/employees_app/templates/base.html
chmod -x src/shared/services/payments.py
chmod -x src/clients_app/routes/web.py
chmod -x src/clients_app/routes/api.py
chmod -x src/clients_app/requirements.txt
chmod -x docker-compose.yml
chmod -x src/static_content/nginx.conf
chmod -x src/employees_app/wsgi.py
chmod -x src/employees_app/requirements.txt
chmod -x FINAL_SUMMARY.txt
chmod -x src/shared/config.py
chmod -x .github/workflows/pronto-ci.yml
chmod -x src/shared/validation.py
chmod -x src/shared/error_handlers.py
chmod -x src/clients_app/__init__.py
chmod -x AUDITORIA_BUENAS_PRACTICAS.md
chmod -x src/clients_app/routes/__init__.py
chmod -x src/clients_app/wsgi.py
chmod -x conf/general.env
chmod -x QUICKSTART.md
chmod -x src/shared/db.py
chmod -x MEJORAS_APLICADAS.md
chmod -x src/employees_app/Dockerfile
chmod -x src/clients_app/Dockerfile
chmod -x conf/secrets.env.bak.2025-11-04-192157
chmod -x src/employees_app/routes/__init__.py
chmod -x src/clients_app/static/css/styles.css
chmod -x src/employees_app/app.py
chmod -x RESUMEN_DEBUG.md
chmod -x src/clients_app/templates/thank_you_old.html
chmod -x src/employees_app/routes/api.py
chmod -x src/clients_app/app.py
chmod -x data/.gitignore 2>/dev/null || echo "  ⚠ No se pudo cambiar data/.gitignore"
chmod -x src/employees_app/services/menu_service.py
chmod -x TESTING.md
chmod -x src/employees_app/routes/dashboard.py
chmod -x src/static_content/assets/.gitignore 2>/dev/null || echo "  ⚠ No se pudo cambiar src/static_content/assets/.gitignore"
chmod -x src/shared/schemas.py
chmod -x src/shared/auth/__init__.py
chmod -x src/static_content/styles.css
chmod -x src/clients_app/templates/base_old.html
chmod -x src/clients_app/services/order_service.py
chmod -x src/static_content/Dockerfile
chmod -x src/shared/__init__.py
chmod -x src/shared/services/__init__.py

echo "✓ Permisos removidos"
echo ""

# Archivos que SÍ deberían ser ejecutables (tienen shebang)
echo "🔑 Agregando permisos de ejecución a scripts..."
chmod +x scripts/generate_product_images.py
chmod +x scripts/generate_profile_avatars.py

echo "✓ Permisos agregados"
echo ""

echo "✅ ¡Permisos corregidos!"
echo ""
echo "Ahora ejecuta: git add -A && pre-commit run --all-files"
