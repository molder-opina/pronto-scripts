#!/usr/bin/env bash
# Script para crear commit y push usando PENDING_CHANGES.md
# Solo limpia PENDING_CHANGES.md después de confirmar que el push fue exitoso

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PENDING_FILE="${PROJECT_ROOT}/PENDING_CHANGES.md"
TEMP_MSG_FILE="${PROJECT_ROOT}/.commit_message_temp.txt"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                       ║${NC}"
echo -e "${BLUE}║   📝 COMMIT Y PUSH DE CAMBIOS PENDIENTES             ║${NC}"
echo -e "${BLUE}║                                                       ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Verificar que existe PENDING_CHANGES.md
if [[ ! -f "${PENDING_FILE}" ]]; then
    echo -e "${RED}❌ Error: ${PENDING_FILE} no encontrado${NC}"
    exit 1
fi

# Leer el contenido de PENDING_CHANGES.md
echo -e "${YELLOW}📖 Leyendo cambios pendientes...${NC}"

# Extraer solo la sección de cambios (después de "## Cambios en esta sesión")
CHANGES_CONTENT=$(awk '/## Cambios en esta sesión/,0' "${PENDING_FILE}" | tail -n +2)

# Verificar que hay cambios documentados
if [[ -z "${CHANGES_CONTENT// }" ]] || [[ "${CHANGES_CONTENT}" == *"_(Aquí se documentarán los cambios a medida que se realicen)_"* ]]; then
    echo -e "${RED}❌ Error: No hay cambios documentados en PENDING_CHANGES.md${NC}"
    echo -e "${YELLOW}   Documenta tus cambios antes de hacer commit${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Cambios pendientes encontrados${NC}"
echo ""
echo -e "${YELLOW}Contenido del commit:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "${CHANGES_CONTENT}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Preguntar confirmación
read -p "¿Continuar con commit y push? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️  Operación cancelada${NC}"
    exit 0
fi

# Crear mensaje de commit temporal
echo "${CHANGES_CONTENT}" > "${TEMP_MSG_FILE}"

# Agregar footer al commit
echo "" >> "${TEMP_MSG_FILE}"
echo "🤖 Generated with [Claude Code](https://claude.com/claude-code)" >> "${TEMP_MSG_FILE}"
echo "" >> "${TEMP_MSG_FILE}"
echo "Co-Authored-By: Claude <noreply@anthropic.com>" >> "${TEMP_MSG_FILE}"

cd "${PROJECT_ROOT}"

# Verificar si hay cambios para commitear
if git diff --quiet && git diff --cached --quiet; then
    echo -e "${YELLOW}⚠️  No hay cambios para commitear${NC}"
    rm -f "${TEMP_MSG_FILE}"
    exit 0
fi

# Mostrar archivos que se van a commitear
echo ""
echo -e "${BLUE}📦 Archivos modificados:${NC}"
git status --short
echo ""

# Agregar todos los cambios
echo -e "${YELLOW}📥 Agregando cambios al stage...${NC}"
git add -A

# Crear commit
echo -e "${YELLOW}💾 Creando commit...${NC}"
if git commit -F "${TEMP_MSG_FILE}"; then
    echo -e "${GREEN}✅ Commit creado exitosamente${NC}"

    # Mostrar el commit
    echo ""
    echo -e "${BLUE}📋 Commit creado:${NC}"
    git log -1 --oneline
    echo ""

    # Hacer push
    echo -e "${YELLOW}🚀 Haciendo push al origin...${NC}"
    CURRENT_BRANCH=$(git branch --show-current)

    if git push origin "${CURRENT_BRANCH}"; then
        echo -e "${GREEN}✅ Push exitoso a origin/${CURRENT_BRANCH}${NC}"
        echo ""

        # Limpiar PENDING_CHANGES.md solo después de push exitoso
        echo -e "${YELLOW}🧹 Limpiando PENDING_CHANGES.md...${NC}"
        cat > "${PENDING_FILE}" <<'EOF'
# Cambios Pendientes de Commit

Este archivo documenta los cambios realizados durante la sesión actual que aún no han sido commiteados.

## Instrucciones

- Durante el desarrollo, documenta aquí cada cambio significativo
- Al finalizar la sesión de trabajo, usa este archivo para crear el mensaje de commit
- Después del commit, limpia este archivo dejando solo el encabezado

## Formato de entrada

```
### [Tipo] Título breve del cambio

**Archivos**: archivo1.py (líneas X-Y), archivo2.ts (líneas A-B)
**Descripción**: Qué se cambió y por qué
**Impacto**: Qué features o funcionalidades se ven afectadas
```

---

## Cambios en esta sesión

_(Aquí se documentarán los cambios a medida que se realicen)_
EOF

        echo -e "${GREEN}✅ PENDING_CHANGES.md limpiado${NC}"
        echo ""
        echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                                                       ║${NC}"
        echo -e "${GREEN}║   ✅ COMMIT Y PUSH COMPLETADO EXITOSAMENTE           ║${NC}"
        echo -e "${GREEN}║                                                       ║${NC}"
        echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${RED}❌ Error al hacer push${NC}"
        echo -e "${YELLOW}⚠️  El commit fue creado pero el push falló${NC}"
        echo -e "${YELLOW}   PENDING_CHANGES.md NO fue limpiado${NC}"
        echo -e "${YELLOW}   Revisa el error y ejecuta manualmente: git push origin ${CURRENT_BRANCH}${NC}"
        rm -f "${TEMP_MSG_FILE}"
        exit 1
    fi
else
    echo -e "${RED}❌ Error al crear commit (probablemente falló un pre-commit hook)${NC}"
    echo -e "${YELLOW}   PENDING_CHANGES.md NO fue limpiado${NC}"
    echo -e "${YELLOW}   Revisa los errores arriba y corrige antes de reintentar${NC}"
    rm -f "${TEMP_MSG_FILE}"
    exit 1
fi

# Limpiar archivo temporal
rm -f "${TEMP_MSG_FILE}"

echo ""
echo -e "${BLUE}🎉 ¡Listo! Cambios commiteados y pusheados${NC}"
