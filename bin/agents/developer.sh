#!/usr/bin/env bash
set -e

echo "🔍 [AGENTE DEVELOPER] Iniciando revisión de código..."

EXIT_CODE=0

# 1. Check for TODOs and FIXMEs
echo "   - Buscando TODOs y FIXMEs..."
if grep -rE "TODO|FIXME" src/ --include="*.py" --include="*.js" --include="*.ts" > /dev/null; then
    echo "   ⚠️  Advertencia: Se encontraron TODOs o FIXMEs en el código."
    # grep -rE "TODO|FIXME" src/ --include="*.py" --include="*.js" --include="*.ts" | head -n 5
    # Don't fail, just warn
else
    echo "   ✅ Código limpio de marcadores temporales."
fi

# 2. Check for console.log/print in production code (stricter than pre-commit maybe?)
echo "   - Buscando print() olvidados en Python..."
if grep -rn "^\s*print(" src/ --include="*.py" --exclude-dir="pronto_employees_backup" --exclude-dir="bin" --exclude-dir=".venv" --exclude-dir="orchestrator" 2>/dev/null | grep -v "scripts/" | grep -v "test" > /dev/null; then
    echo "   ❌ Error: Se encontraron 'print()' en código de producción (Python). Usa logger."
    grep -rn "^\s*print(" src/ --include="*.py" --exclude-dir="pronto_employees_backup" --exclude-dir="bin" --exclude-dir=".venv" --exclude-dir="orchestrator" 2>/dev/null | grep -v "scripts/" | grep -v "test" | head -n 3
    EXIT_CODE=1
else
    echo "   ✅ No hay 'print()' en código productivo."
fi

# 3. Check for hardcoded static URLs in templates (MUST use short variables)
echo "   - Verificando URLs de contenido estático en templates..."
HARDCODE_STATIC_URLS=$(grep -rn "pronto_static_container_host.*/assets" src/ --include="*.html" 2>/dev/null || true)
if [ -n "$HARDCODE_STATIC_URLS" ]; then
    echo "   ❌ Error: Se encontraron URLs hardcodeadas de contenido estático en templates."
    echo "      Usa las variables cortas: assets_css, assets_css_clients, assets_css_employees, etc."
    echo "$HARDCODE_STATIC_URLS" | head -n 5
    EXIT_CODE=1
else
    echo "   ✅ Templates usan variables cortas para assets."
fi

# 4. Check for hardcoded static URLs in Python code
echo "   - Verificando URLs de contenido estático en Python..."
HARDCODE_STATIC_PY=$(grep -rn "pronto_static_container_host.*assets" src/ --include="*.py" 2>/dev/null | grep -v "def get_" | grep -v "config\." | grep -v "app.config\[" | grep -v "#" | grep -v "branding.py" || true)
if [ -n "$HARDCODE_STATIC_PY" ]; then
    echo "   ❌ Error: Se encontraron URLs hardcodeadas de contenido estático en Python."
    echo "      Usa las funciones helper de branding.py: get_assets_css(), get_assets_js(), etc."
    echo "$HARDCODE_STATIC_PY" | head -n 5
    EXIT_CODE=1
else
    echo "   ✅ Python usa funciones helper para assets."
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "👨‍💻 [AGENTE DEVELOPER] Visto Bueno (VoBo) ✅"
else
    echo "👨‍💻 [AGENTE DEVELOPER] Rechazado ❌"
fi

exit $EXIT_CODE
