#!/bin/bash

# Script para guardar cambios, hacer push y cambiar de rama
# Uso: ./bin/sync.sh <nombre-de-rama-destino>

set -e

if [ -z "$1" ]; then
    echo "Error: Debes proporcionar el nombre de la rama destino"
    echo "Uso: ./bin/sync.sh <nombre-de-rama>"
    exit 1
fi

TARGET_BRANCH=$1
CURRENT_BRANCH=$(git branch --show-current)

echo "🔄 Rama actual: $CURRENT_BRANCH"
echo "🎯 Rama destino: $TARGET_BRANCH"
echo ""

# Verificar si hay cambios
if [[ -n $(git status -s) ]]; then
    echo "📝 Detectados cambios en el filesystem"

    # Agregar todos los cambios
    echo "➕ Agregando cambios..."
    git add -A

    # Hacer commit
    echo "💾 Creando commit..."
    COMMIT_MSG="chore: Guardar cambios antes de cambiar a $TARGET_BRANCH

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

    git commit -m "$COMMIT_MSG"

    # Push a la rama actual
    echo "🚀 Empujando cambios a origin/$CURRENT_BRANCH..."
    git push -u origin "$CURRENT_BRANCH"

    echo "✅ Cambios guardados y empujados exitosamente"
else
    echo "ℹ️  No hay cambios que guardar"
fi

echo ""
echo "🔀 Cambiando a la rama: $TARGET_BRANCH"

# Fetch para asegurar que tenemos las últimas ramas
git fetch origin

# Verificar si la rama existe localmente
if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    # La rama existe localmente
    git checkout "$TARGET_BRANCH"
    echo "✅ Cambiado a rama local existente: $TARGET_BRANCH"
elif git show-ref --verify --quiet "refs/remotes/origin/$TARGET_BRANCH"; then
    # La rama existe en remoto pero no localmente
    git checkout -b "$TARGET_BRANCH" "origin/$TARGET_BRANCH"
    echo "✅ Creada rama local desde remoto: $TARGET_BRANCH"
else
    echo "❌ Error: La rama '$TARGET_BRANCH' no existe ni local ni remotamente"
    exit 1
fi

echo ""
echo "🎉 Proceso completado exitosamente"
