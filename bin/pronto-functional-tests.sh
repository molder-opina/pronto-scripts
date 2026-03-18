#!/bin/bash
# Script Maestro de Pruebas Funcionales PRONTO
# Ejecuta todas las fases de testing y genera reporte

set -e

echo "========================================"
echo "PRONTO - PRUEBAS FUNCIONALES COMPLETAS"
echo "========================================"
echo "Fecha: $(date)"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRONTO_ROOT="$(dirname "$SCRIPT_DIR")"

# Directorio para logs
LOG_DIR="$PRONTO_ROOT/pronto-logs/tests"
mkdir -p "$LOG_DIR"

REPORT_FILE="$LOG_DIR/functional-tests-$(date +%Y%m%d-%H%M%S).md"
SUMMARY_FILE="$LOG_DIR/functional-tests-summary-$(date +%Y%m%d-%H%M%S).txt"

# Contadores globales
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
CRITICAL_ERRORS=0

# Función para ejecutar una fase
run_phase() {
    local phase_num="$1"
    local phase_name="$2"
    local phase_script="$3"
    local is_critical="$4"
    
    echo ""
    echo "========================================"
    echo "EJECUTANDO FASE $phase_num: $phase_name"
    echo "========================================"
    echo ""
    
    if [ ! -f "$phase_script" ]; then
        echo "⚠ Script no encontrado: $phase_script"
        echo "Saltando fase $phase_num..."
        return 0
    fi
    
    # Ejecutar script y capturar salida
    local phase_output
    local phase_exit
    
    if phase_output=$("$phase_script" 2>&1); then
        phase_exit=0
    else
        phase_exit=1
    fi
    
    # Extraer métricas de la salida
    local passed=$(echo "$phase_output" | grep -oP "Tests Pasados: \K\d+" || echo "0")
    local failed=$(echo "$phase_output" | grep -oP "Tests Fallidos: \K\d+" || echo "0")
    
    TOTAL_TESTS=$((TOTAL_TESTS + passed + failed))
    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))
    
    # Guardar en reporte
    echo "## Fase $phase_num: $phase_name" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    echo "$phase_output" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    if [ $phase_exit -eq 0 ]; then
        echo "✓ Fase $phase_num completada"
        return 0
    else
        echo "✗ Fase $phase_num falló"
        if [ "$is_critical" = "true" ]; then
            ((CRITICAL_ERRORS++))
        fi
        return 1
    fi
}

# Inicializar reporte
cat > "$REPORT_FILE" << EOF
# Reporte de Pruebas Funcionales PRONTO

**Fecha:** $(date)
**Sistema:** PRONTO
**Versión:** $(grep "PRONTO_SYSTEM_VERSION" "$PRONTO_ROOT/.env" 2>/dev/null | cut -d= -f2 || echo "N/A")

## Resumen Ejecutivo

Este reporte documenta los resultados de las pruebas funcionales del sistema PRONTO.

---

EOF

# Ejecutar todas las fases
run_phase "1" "Infraestructura y Base de Datos" "$SCRIPT_DIR/test-phase-1.sh" "true"
run_phase "2" "Autenticación y Autorización" "$SCRIPT_DIR/test-phase-2.sh" "true"
run_phase "3" "Menú y Catálogo" "$SCRIPT_DIR/test-phase-3.sh" "false"
run_phase "4" "Órdenes y State Machine" "$SCRIPT_DIR/test-phase-4.sh" "true"
run_phase "5" "Pagos y Sesiones" "$SCRIPT_DIR/test-phase-5.sh" "true"
run_phase "6" "Frontend Cliente" "$SCRIPT_DIR/test-phase-6.sh" "false"
run_phase "7" "Frontend Mesero" "$SCRIPT_DIR/test-phase-7.sh" "false"
run_phase "8" "Frontend Cocina" "$SCRIPT_DIR/test-phase-8.sh" "false"
run_phase "9" "Frontend Cajero" "$SCRIPT_DIR/test-phase-9.sh" "true"
run_phase "10" "Frontend Admin" "$SCRIPT_DIR/test-phase-10.sh" "false"
run_phase "11" "Flujo End-to-End" "$SCRIPT_DIR/test-phase-11.sh" "true"
run_phase "12" "Performance y Seguridad" "$SCRIPT_DIR/test-phase-12.sh" "false"

# Generar resumen final
echo ""
echo "========================================"
echo "RESUMEN FINAL DE PRUEBAS"
echo "========================================"
echo ""
echo "Total Tests Ejecutados: $TOTAL_TESTS"
echo "Tests Pasados: $TOTAL_PASSED"
echo "Tests Fallidos: $TOTAL_FAILED"
echo "Errores Críticos: $CRITICAL_ERRORS"
echo ""

# Calcular porcentaje de éxito
if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($TOTAL_PASSED/$TOTAL_TESTS)*100}")
    echo "Tasa de Éxito: ${SUCCESS_RATE}%"
else
    echo "Tasa de Éxito: N/A"
fi

echo ""

# Finalizar reporte
cat >> "$REPORT_FILE" << EOF
## Resumen Final

| Métrica | Valor |
|---------|-------|
| Total Tests | $TOTAL_TESTS |
| Tests Pasados | $TOTAL_PASSED |
| Tests Fallidos | $TOTAL_FAILED |
| Errores Críticos | $CRITICAL_ERRORS |
| Tasa de Éxito | ${SUCCESS_RATE}% |

EOF

if [ $CRITICAL_ERRORS -eq 0 ] && [ $TOTAL_FAILED -eq 0 ]; then
    echo "✓ TODAS LAS PRUEBAS PASARON EXITOSAMENTE"
    echo ""
    echo "El sistema está listo para producción."
    cat >> "$REPORT_FILE" << EOF
## Estado: ✅ APROBADO

Todas las pruebas funcionales pasaron correctamente.
EOF
    EXIT_CODE=0
elif [ $CRITICAL_ERRORS -eq 0 ]; then
    echo "⚠ PRUEBAS COMPLETADAS CON ADVERTENCIAS"
    echo ""
    echo "Algunos tests no críticos fallaron, pero el sistema es funcional."
    cat >> "$REPORT_FILE" << EOF
## Estado: ⚠️ ADVERTENCIA

Las pruebas completaron pero algunos tests no críticos fallaron.
EOF
    EXIT_CODE=0
else
    echo "✗ PRUEBAS FALLARON - HAY ERRORES CRÍTICOS"
    echo ""
    echo "Se encontraron $CRITICAL_ERRORS errores críticos que deben corregirse."
    cat >> "$REPORT_FILE" << EOF
## Estado: ❌ RECHAZADO

Se encontraron $CRITICAL_ERRORS errores críticos que deben corregirse antes del deploy.
EOF
    EXIT_CODE=1
fi

echo ""
echo "========================================"
echo "REPORTE GENERADO"
echo "========================================"
echo "Archivo completo: $REPORT_FILE"
echo "Resumen: $SUMMARY_FILE"
echo ""

# Guardar resumen
cat > "$SUMMARY_FILE" << EOF
PRONTO Functional Tests Summary
Date: $(date)
Total: $TOTAL_TESTS
Passed: $TOTAL_PASSED
Failed: $TOTAL_FAILED
Critical: $CRITICAL_ERRORS
Success Rate: ${SUCCESS_RATE}%
Status: $([ $CRITICAL_ERRORS -eq 0 ] && echo "PASSED" || echo "FAILED")
EOF

exit $EXIT_CODE
