#!/usr/bin/env bash
set -e

echo "🗄️  [AGENTE DB SPECIALIST] Analizando base de datos y migraciones..."

EXIT_CODE=0

# 1. Check migration file naming convention
echo "   - Verificando nombres de migraciones..."
INVALID_MIGRATIONS=$(find src/shared/migrations -name "*.sql" ! -name "*_*.sql" ! -name "README.md")
if [ -n "$INVALID_MIGRATIONS" ]; then
    echo "   ❌ Error: Migraciones sin formato correcto (deben ser snake_case y numeradas/fechadas)."
    echo "$INVALID_MIGRATIONS"
    EXIT_CODE=1
else
    echo "   ✅ Nombres de migraciones correctos."
fi

# 2. Check for dangerous operations in migrations
echo "   - Buscando operaciones destructivas..."
if grep -rE "DROP TABLE|DROP COLUMN" src/shared/migrations --include="*.sql" > /dev/null; then
    echo "   ⚠️  Advertencia: Se detectaron operaciones DROP en migraciones. Verificar que no haya pérdida de datos accidental."
    grep -rE "DROP TABLE|DROP COLUMN" src/shared/migrations --include="*.sql" | head -n 3
    # Warn only, sometimes necessary
else
    echo "   ✅ No se detectaron operaciones DROP obvias."
fi

# 3. Check models.py existence
if [ ! -f "src/shared/models.py" ]; then
    echo "   ❌ Error: No se encuentra src/shared/models.py"
    EXIT_CODE=1
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "👨‍据 [AGENTE DB SPECIALIST] Visto Bueno (VoBo) ✅"
else
    echo "👨‍据 [AGENTE DB SPECIALIST] Rechazado ❌"
fi

exit $EXIT_CODE
