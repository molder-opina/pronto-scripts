#!/bin/bash
# limpieza-pronto-app.sh - Script de limpieza automatizado

echo "🧹 Script de Limpieza para Pronto-App"
echo "====================================="

# 1. Limpiar cache de Python
echo "📁 Limpiando cache Python..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
find . -name "*.pyc" -delete
find . -name "*.pyo" -delete
echo "✅ Cache Python limpiado"

# 2. Eliminar source maps
echo "🗺️ Eliminando source maps..."
find src/ -name "*.map" -delete
echo "✅ Source maps eliminados"

# 3. Remover archivos backup y temporales
echo "💾 Limpiando archivos temporales..."
rm -f *.backup *.bak *.tmp *.log page.html
find . -name "*.backup" -delete
find . -name "*.bak" -delete
echo "✅ Archivos temporales eliminados"

# 4. Eliminar imágenes de menú no utilizadas
echo "🖼️ Eliminando imágenes no utilizadas..."
UNUSED_IMAGES=(
    "agua.png" "aros_cebolla.png" "arrachera.png" "cafe_americano.png"
    "cafe_latte.png" "camarones_coco.png" "cerveza.png" "coca_cola.png"
    "consome_pollo.png" "crema_champinones.png" "crema_tomate.png"
    "dedos_queso.png" "enchiladas_rojas.png" "enchiladas_verdes.png"
    "ensalada_caprese.png" "ensalada_cesar.png" "ensalada_mediterranea.png"
    "ensalada_pollo.png" "ensalada_quinoa.png" "fajitas_mixtas.png"
    "filete_pescado.png" "flautas.png" "gorditas.png" "guacamole.png"
)

for img in "${UNUSED_IMAGES[@]}"; do
    rm -f "src/static_content/assets/cafeteria-test/menu/$img"
done
echo "✅ Imágenes no utilizadas eliminadas ($(echo ${#UNUSED_IMAGES[@]}))"

# 5. Mover scripts de desarrollo
echo "📦 Archivando scripts de desarrollo..."
mkdir -p scripts/archived/ 2>/dev/null || true
DEV_SCRIPTS=(
    "check_button_layout.py" "debug_cache.py" "qa_complete_cycle_fixed.py"
    "migrate_dashboard.py" "fix_missing_tables.py"
)

for script in "${DEV_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        mv "$script" scripts/archived/
        echo "   → $script archivado"
    fi
done
echo "✅ Scripts de desarrollo archivados"

# 6. Limpiar archivos de test en build
echo "🧪 Eliminando archivos de test..."
rm -rf src/clients_app/static/js/src/__tests__
rm -rf src/employees_app/static/js/src/__tests__
rm -f test-setup.ts
echo "✅ Archivos de test eliminados"

# 7. Limpiar archivos de backup en templates
echo "📄 Limpiando templates backup..."
find . -name "*.backup" -delete
find . -name "*.bak" -delete
echo "✅ Templates backup eliminados"

# 8. Calcular espacio ahorrado
echo ""
echo "📊 Resultados:"
echo "============"
echo "🖼️ Imágenes de menú eliminadas: ${#UNUSED_IMAGES[@]}"
echo "📁 Directorios __pycache__ eliminados: $(find . -name "__pycache__" -type d | wc -l)"
echo "🗺️ Source maps eliminados: $(find src/ -name "*.map" | wc -l)"
echo "🧪 Archivos de test eliminados: $(find src/ -path "*/__tests__/*" -name "*.ts" | wc -l)"

echo ""
echo "✅ Limpieza completada exitosamente!"
echo "💾 Se recomienda ejecutar este script regularmente"
