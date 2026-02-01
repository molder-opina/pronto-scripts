#!/usr/bin/env bash
# Validación de cambios recientes usando OpenCode AI
# Revisa el código para verificar que no se rompió en las últimas ejecuciones

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parámetros
HOURS=${1:-8}  # Por defecto revisar las últimas 8 horas
MODEL=${2:-"opencode/glm-4.7-free"}  # Modelo OpenCode Cloud (GLM-4.7 Free)

# Directorio temporal para el reporte
REPORT_DIR="$PROJECT_ROOT/tmp/validation-reports"
REPORT_FILE="$REPORT_DIR/validation_$(date +%Y%m%d_%H%M%S).md"

mkdir -p "$REPORT_DIR"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                ║${NC}"
echo -e "${BLUE}║   PRONTO - VALIDACIÓN DE CAMBIOS RECIENTES    ║${NC}"
echo -e "${BLUE}║                                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}⏰ Revisando cambios de las últimas ${HOURS} horas${NC}"
echo -e "${CYAN}🤖 Modelo AI: ${MODEL}${NC}"
echo ""

# Inicializar el reporte markdown
cat > "$REPORT_FILE" << 'EOF'
# Reporte de Validación de Cambios Recientes

**Fecha:** {TIMESTAMP}
**Ventana de tiempo:** {HOURS} horas

---

## 1. Información de Git

EOF

# Reemplazar placeholders
sed -i.bak "s/{TIMESTAMP}/$(date '+%Y-%m-%d %H:%M:%S')/" "$REPORT_FILE"
sed -i.bak "s/{HOURS}/${HOURS}/" "$REPORT_FILE"
rm -f "$REPORT_FILE.bak"

echo -e "${YELLOW}[1/5]${NC} Revisando log de commits..."
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

COMMIT_LOG=$(cd "$PROJECT_ROOT" && git log --since="${HOURS} hours ago" --oneline --all 2>&1 || echo "No hay commits recientes")

if [ -z "$COMMIT_LOG" ] || echo "$COMMIT_LOG" | grep -q "No hay commits recientes"; then
    echo -e "${YELLOW}⚠️  No hay commits en las últimas ${HOURS} horas${NC}"
    echo "" >> "$REPORT_FILE"
    echo "**No hay commits en las últimas ${HOURS} horas**" >> "$REPORT_FILE"
else
    echo -e "${GREEN}✓${NC} Commits encontrados:"
    echo "$COMMIT_LOG" | head -20
    echo "" >> "$REPORT_FILE"
    echo "### Commits Recientes" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
    echo "$COMMIT_LOG" >> "$REPORT_FILE"
    echo '```' >> "$REPORT_FILE"
fi
echo ""

echo -e "${YELLOW}[2/5]${NC} Analizando estadísticas de cambios..."
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

STATS=$(cd "$PROJECT_ROOT" && git diff --stat HEAD~8..HEAD 2>&1 || echo "No hay estadísticas disponibles")

echo -e "${GREEN}✓${NC} Estadísticas de cambios:"
echo "$STATS" | head -30
echo "" >> "$REPORT_FILE"
echo "### Estadísticas de Cambios" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo "$STATS" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo ""

echo -e "${YELLOW}[3/5]${NC} Verificando estado de git..."
echo -e "${YELLOW}[3/5]${NC} Verificando estado de git..."
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

STATUS=$(cd "$PROJECT_ROOT" && git status --short 2>&1)

echo -e "${GREEN}✓${NC} Estado actual:"
echo "$STATUS" | head -20
echo "" >> "$REPORT_FILE"
echo "### Estado Actual" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo "$STATUS" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo ""

echo -e "${YELLOW}[4/5]${NC} Ejecutando suite de pruebas..."
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

TEST_OUTPUT_FILE="$REPORT_DIR/test_output_$(date +%Y%m%d_%H%M%S).txt"
TEST_START_TIME=$(date +%s)

if bash "$SCRIPT_DIR/test-all.sh" > "$TEST_OUTPUT_FILE" 2>&1; then
    TEST_RESULT="✅ PASSED"
    TEST_EXIT_CODE=0
    echo -e "${GREEN}✓${NC} Pruebas completadas exitosamente"
else
    TEST_RESULT="❌ FAILED"
    TEST_EXIT_CODE=1
    echo -e "${RED}✗${NC} Algunas pruebas fallaron"
fi

TEST_END_TIME=$(date +%s)
TEST_DURATION=$((TEST_END_TIME - TEST_START_TIME))

echo "" >> "$REPORT_FILE"
echo "## 2. Resultados de Pruebas" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "**Estado:** ${TEST_RESULT}" >> "$REPORT_FILE"
echo "**Duración:** ${TEST_DURATION} segundos" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "### Salida de Pruebas" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
tail -100 "$TEST_OUTPUT_FILE" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo ""

echo -e "${YELLOW}[5/5]${NC} Analizando resultados con AI..."
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Preparar prompt para OpenCode
cat > "$REPORT_DIR/opencode_prompt.txt" << EOF
Eres un ingeniero de software experto revisando el código del proyecto Pronto (sistema de gestión de restaurantes).

Contexto:
- Ventana de tiempo: últimas ${HOURS} horas
- Estado de pruebas: ${TEST_RESULT}

Tarea:
1. Analiza los cambios recientes y determina si podrían haber roto algo
2. Revisa los resultados de las pruebas y explica cualquier fallo
3. Identifica archivos críticos que fueron modificados
4. Propone acciones correctivas si es necesario
5. Da un veredicto final: ✅ CÓDIGO SEGURO o ⚠️ NECESITA ATENCIÓN

Responde en formato Markdown con:
- **Resumen Ejecutivo**: 2-3 líneas
- **Análisis de Cambios Críticos**
- **Diagnóstico de Fallos de Pruebas** (si aplica)
- **Recomendaciones**
- **Veredicto Final**

EOF

echo -e "${CYAN}📝 Ejecutando OpenCode con modelo ${MODEL}...${NC}"

# Ejecutar opencode run con el modelo cloud
PROMPT_FILE="$REPORT_DIR/opencode_prompt.txt"
AI_OUTPUT=$(cd "$PROJECT_ROOT" && cat "$PROMPT_FILE" | opencode run \
    --model "${MODEL}" \
    --file "$REPORT_FILE" \
    2>&1 || echo "Error ejecutando OpenCode")

echo "" >> "$REPORT_FILE"
echo "## 3. Análisis con OpenCode AI" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo "$AI_OUTPUT" >> "$REPORT_FILE"
echo '```' >> "$REPORT_FILE"
echo ""

# Resumen final
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                ║${NC}"
echo -e "${BLUE}║   RESUMEN DE VALIDACIÓN                       ║${NC}"
echo -e "${BLUE}║                                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📊 Resultado de pruebas: ${TEST_RESULT}${NC}"
echo -e "${CYAN}⏱️  Duración: ${TEST_DURATION}s${NC}"
echo -e "${CYAN}📝 Reporte: ${REPORT_FILE}${NC}"
echo ""
echo -e "${BLUE}Veredicto de OpenCode:${NC}"
echo -e "${CYAN}─────────────────────────────────${NC}"
echo "$AI_OUTPUT" | grep -E "✅|⚠️|Veredicto|Resumen" | head -10
echo ""

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ Validación completada con éxito${NC}"
    exit 0
else
    echo -e "${RED}❌ Validación detectó problemas${NC}"
    echo -e "${YELLOW}Revisa el reporte completo en: ${REPORT_FILE}${NC}"
    exit 1
fi
