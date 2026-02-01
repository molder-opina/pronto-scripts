#!/usr/bin/env bash
set -e

echo "👑 [AGENTE SUPER ADMIN] Validando integridad del sistema y /system..."

EXIT_CODE=0

# 1. Check for system routes
if ! grep -r "system_bp" src/employees_app/app.py > /dev/null; then
    echo "   ❌ Error: No se detectó el blueprint de sistema (system_bp) en la app."
    EXIT_CODE=1
fi

# 2. Check for JWT Scope Guard protection
if ! grep -r "apply_jwt_scope_guard" src/employees_app/app.py > /dev/null; then
    echo "   ❌ Error: El Scope Guard no está aplicado en el punto de entrada."
    EXIT_CODE=1
fi

# 3. Check for security middleware
if [ ! -f "src/shared/security_middleware.py" ]; then
    echo "   ❌ Error: No se encuentra security_middleware.py"
    EXIT_CODE=1
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "👑 [AGENTE SUPER ADMIN] Visto Bueno (VoBo) ✅"
else
    echo "👑 [AGENTE SUPER ADMIN] Rechazado ❌"
fi

exit $EXIT_CODE
