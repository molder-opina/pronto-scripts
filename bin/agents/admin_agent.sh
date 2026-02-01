#!/usr/bin/env bash
set -e

echo "👨‍💼 [AGENTE ADMIN] Validando módulos administrativos (/admin)..."

EXIT_CODE=0

# 1. Check for Admin Sections template
if [ ! -f "src/employees_app/templates/includes/_admin_sections.html" ]; then
    echo "   ❌ Error: No se encuentra el template _admin_sections.html"
    EXIT_CODE=1
fi

# 2. Check for role management
if ! grep -r "Permission" src/shared/permissions.py > /dev/null; then
    echo "   ❌ Error: El sistema de permisos no parece estar configurado correctamente."
    EXIT_CODE=1
fi

# 3. Check for business config service
if [ ! -f "src/shared/services/business_config_service.py" ]; then
    echo "   ❌ Error: Falta el servicio de configuración del negocio."
    EXIT_CODE=1
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "👨‍💼 [AGENTE ADMIN] Visto Bueno (VoBo) ✅"
else
    echo "👨‍💼 [AGENTE ADMIN] Rechazado ❌"
fi

exit $EXIT_CODE
