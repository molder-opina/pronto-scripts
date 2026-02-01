#!/usr/bin/env bash
# Script simplificado para recopilar información de validación
# Uso: bash bin/collect-validation-info.sh | opencode run --model opencode/glm-4.7-free

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HOURS=${1:-8}

echo "# VALIDACIÓN DE CAMBIOS RECIENTES - PRONTO"
echo ""
echo "## Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo "## Ventana de tiempo: Últimas ${HOURS} horas"
echo ""

echo "## 1. LOG DE COMMITS RECIENTES"
echo '```'
cd "$PROJECT_ROOT" && git log --since="${HOURS} hours ago" --oneline --all || echo "No hay commits recientes"
echo '```'
echo ""

echo "## 2. ESTADÍSTICAS DE CAMBIOS"
echo '```'
cd "$PROJECT_ROOT" && git diff --stat HEAD~8..HEAD || echo "No hay estadísticas disponibles"
echo '```'
echo ""

echo "## 3. ESTADO ACTUAL DE GIT"
echo '```'
cd "$PROJECT_ROOT" && git status --short
echo '```'
echo ""

echo "## 4. ARCHIVOS MODIFICADOS CRÍTICOS"
echo '```'
cd "$PROJECT_ROOT" && git diff --name-only HEAD~8..HEAD | grep -E "\.(py|js|ts|html|sql)$" || echo "No se encontraron archivos modificados"
echo '```'
echo ""

echo "## 5. PRUEBAS - VERIFICACIÓN DE SALUD DEL SISTEMA"
echo ""

# Verificar servicios
echo "### Verificación de Servicios"
if curl -sf http://localhost:6081/api/health > /dev/null 2>&1; then
    echo "✅ Employee API: OK"
else
    echo "❌ Employee API: NO RESPONDE"
fi

if curl -sf http://localhost:6080/api/health > /dev/null 2>&1; then
    echo "✅ Client API: OK"
else
    echo "❌ Client API: NO RESPONDE"
fi

# Ejecutar tests (capturar solo el resumen)
echo ""
echo "### Ejecutando Pruebas..."
echo ""

TEST_OUTPUT=$("$SCRIPT_DIR/test-all.sh" 2>&1)
TEST_EXIT_CODE=$?

echo "**Estado de pruebas:** $([ $TEST_EXIT_CODE -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
echo ""
echo "**Resumen de salida:**"
echo '```'
echo "$TEST_OUTPUT" | tail -50
echo '```'
echo ""

echo "## 6. ARCHIVOS ELIMINADOS"
echo '```'
cd "$PROJECT_ROOT" && git diff HEAD~8..HEAD --diff-filter=D --name-only || echo "No hay archivos eliminados"
echo '```'
echo ""

echo "## 7. ARCHIVOS AÑADIDOS"
echo '```'
cd "$PROJECT_ROOT" && git diff HEAD~8..HEAD --diff-filter=A --name-only || echo "No hay archivos nuevos"
echo '```'
echo ""

echo "---"
echo ""
echo "## INSTRUCCIONES PARA EL ANÁLISIS"
echo ""
echo "Por favor analiza esta información y proporciona:"
echo "1. **Resumen Ejecutivo**: ¿El código parece seguro o hay riesgos?"
echo "2. **Análisis de Cambios Críticos**: ¿Qué archivos importantes cambiaron?"
echo "3. **Diagnóstico de Fallos**: Si las pruebas fallaron, ¿por qué?"
echo "4. **Riesgos Identificados**: ¿Qué podría romperse?"
echo "5. **Recomendaciones**: ¿Qué acciones se deben tomar?"
echo "6. **Veredicto Final**: ✅ CÓDIGO SEGURO o ⚠️ NECESITA ATENCIÓN"
echo ""
