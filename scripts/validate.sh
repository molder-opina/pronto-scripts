#!/usr/bin/env bash
# Script de validación completo - Ejecuta todos los chequeos que se ejecutarían en commit
# Útil para ejecutar manualmente antes de hacer commit

set -e

echo "🔍 Ejecutando validaciones completas..."
echo ""

# Ejecutar todos los hooks de pre-commit
source .venv/bin/activate
pre-commit run --all-files

echo ""
echo "✅ Todas las validaciones pasaron exitosamente!"
echo ""
echo "Ahora puedes hacer commit con:"
echo "  git add ."
echo "  git commit -m 'tu mensaje'"
