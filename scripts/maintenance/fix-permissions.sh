#!/bin/bash
# =============================================================================
# Script para corregir permisos de archivos
# =============================================================================

set -e

echo "🔧 Corrigiendo permisos de archivos..."
echo ""

# Archivos que NO deberían ser ejecutables
echo "📝 Removiendo permisos de ejecución de archivos que no lo necesitan..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

FILES_TO_FIX=(
  "pronto-employees/src/pronto_employees/services/order_service.py"
  "pronto-employees/src/pronto_employees/__init__.py"
  "conf/secrets.env"
  "pronto-libs/src/pronto_shared/services/notifications.py"
  "pronto-employees/src/pronto_employees/decorators.py"
  "pronto-employees/src/pronto_employees/services/__init__.py"
  "pronto-libs/src/pronto_shared/services/seed.py"
  "pronto-employees/src/pronto_employees/services/role_service.py"
  "pronto-libs/src/pronto_shared/auth/service.py"
  "pronto-employees/src/pronto_employees/services/employee_service.py"
  "pronto-libs/src/pronto_shared/security.py"
  "pronto-libs/src/pronto_shared/logging_config.py"
  "RESUMEN_IMPLEMENTACION.md"
  "conf/general.env.bak.2025-11-04-192157"
  "pronto-static/src/static_content/assets/css/employees/styles.css"
  "pronto-client/src/pronto_clients/services/__init__.py"
  "pronto-libs/src/pronto_shared/constants.py"
  "pronto-client/src/pronto_clients/services/menu_service.py"
  "pronto-libs/src/pronto_shared/serializers.py"
  "pronto-libs/src/pronto_shared/security_middleware.py"
  "pronto-employees/src/pronto_employees/templates/base.html"
  "pronto-libs/src/pronto_shared/services/payments.py"
  "pronto-client/src/pronto_clients/routes/web.py"
  "pronto-client/src/pronto_clients/routes/api.py"
  "pronto-client/requirements.txt"
  "docker-compose.yml"
  "pronto-static/src/static_content/nginx.conf"
  "pronto-employees/src/pronto_employees/wsgi.py"
  "pronto-employees/requirements.txt"
  "FINAL_SUMMARY.txt"
  "pronto-libs/src/pronto_shared/config.py"
  ".github/workflows/pronto-ci.yml"
  "pronto-libs/src/pronto_shared/validation.py"
  "pronto-libs/src/pronto_shared/error_handlers.py"
  "pronto-client/src/pronto_clients/__init__.py"
  "AUDITORIA_BUENAS_PRACTICAS.md"
  "pronto-client/src/pronto_clients/routes/__init__.py"
  "pronto-client/src/pronto_clients/wsgi.py"
  "conf/general.env"
  "QUICKSTART.md"
  "pronto-libs/src/pronto_shared/db.py"
  "MEJORAS_APLICADAS.md"
  "pronto-employees/Dockerfile"
  "pronto-client/Dockerfile"
  "conf/secrets.env.bak.2025-11-04-192157"
  "pronto-employees/src/pronto_employees/routes/__init__.py"
  "pronto-static/src/static_content/assets/css/clients/styles.css"
  "pronto-employees/src/pronto_employees/app.py"
  "RESUMEN_DEBUG.md"
  "pronto-client/src/pronto_clients/templates/thank_you_old.html"
  "pronto-employees/src/pronto_employees/routes/api.py"
  "pronto-client/src/pronto_clients/app.py"
  "data/.gitignore"
  "pronto-employees/src/pronto_employees/services/menu_service.py"
  "TESTING.md"
  "pronto-employees/src/pronto_employees/routes/dashboard.py"
  "pronto-static/src/static_content/assets/.gitignore"
  "pronto-libs/src/pronto_shared/schemas.py"
  "pronto-libs/src/pronto_shared/auth/__init__.py"
  "pronto-static/src/static_content/styles.css"
  "pronto-client/src/pronto_clients/templates/base_old.html"
  "pronto-client/src/pronto_clients/services/order_service.py"
  "pronto-static/src/static_content/Dockerfile"
  "pronto-libs/src/pronto_shared/__init__.py"
  "pronto-libs/src/pronto_shared/services/__init__.py"
)

for file in "${FILES_TO_FIX[@]}"; do
  if [ -f "${REPO_ROOT}/${file}" ]; then
    chmod -x "${REPO_ROOT}/${file}"
  fi
done

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
