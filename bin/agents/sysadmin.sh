#!/usr/bin/env bash
set -e

echo "🛡️  [AGENTE SYSADMIN] Verificando infraestructura y seguridad..."

EXIT_CODE=0

# 1. Check for .env files committed
echo "   - Buscando archivos .env commiteados..."
# This is tricky in a pre-commit hook as git grep looks at tracked files
if git ls-files | grep "\.env$" | grep -v "\.example" | grep -v "\.template" > /dev/null; then
    echo "   ❌ Error: Archivos .env detectados en el repositorio."
    git ls-files | grep "\.env$"
    EXIT_CODE=1
else
    echo "   ✅ Sin archivos .env expuestos."
fi

# 2. Check Dockerfiles for root user
echo "   - Verificando usuario en Dockerfiles..."
DOCKERFILES=$(find . -name "Dockerfile*")
for dockerfile in $DOCKERFILES; do
    if ! grep -q "USER" "$dockerfile"; then
        echo "   ⚠️  Advertencia: $dockerfile no define USER (probablemente corre como root)."
    fi
done

# 3. Check shell scripts for shebang and set -e
echo "   - Verificando scripts de shell..."
SCRIPTS=$(find bin -name "*.sh" -type f)
for script in $SCRIPTS; do
    if ! grep -q "^#!" "$script"; then
        echo "   ⚠️  Advertencia: $script no tiene shebang."
    fi
    # if ! grep -q "set -.*e" "$script"; then
    #     echo "   ⚠️  Advertencia: $script no tiene 'set -e' (fail fast)."
    # fi
done

if [ $EXIT_CODE -eq 0 ]; then
    echo "👷 [AGENTE SYSADMIN] Visto Bueno (VoBo) ✅"
else
    echo "👷 [AGENTE SYSADMIN] Rechazado ❌"
fi

exit $EXIT_CODE
