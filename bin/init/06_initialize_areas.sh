#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/../.."

echo "🔧 Inicializando sistema de Áreas..."

# Try to find migration files
MIGRATION_PATH=""
for path in \
    "${PROJECT_ROOT}/../pronto-libs/src/pronto_shared/migrations" \
    "${PROJECT_ROOT}/../pronto-libs/build/lib/pronto_shared/migrations" \
    "/opt/pronto/lib/pronto_shared/migrations"; do
    if [ -f "${path}/010_create_area_management_functions.sql" ]; then
        MIGRATION_PATH="${path}"
        break
    fi
done

# Verificar migración de funciones de área
echo ""
echo "📋 Paso 1: Verificando migración de funciones de área..."

# Verificar si existe la función create_area
CREATE_AREA_EXISTS=$(docker exec pronto-postgres psql -U pronto -d pronto -tAc "SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'create_area');" 2>/dev/null || echo "false")

if [ "$CREATE_AREA_EXISTS" = "false" ]; then
    echo "⚠️  Migración de funciones de área no encontrada."
    
    if [ -n "$MIGRATION_PATH" ]; then
        echo "   Aplicando: ${MIGRATION_PATH}/010_create_area_management_functions.sql"
        docker exec pronto-postgres psql -U pronto -d pronto -f "${MIGRATION_PATH}/010_create_area_management_functions.sql"
        echo "   ✅ Funciones aplicadas."
    else
        echo "   ⚠️  No se encontró el archivo de migración."
        echo "   Asegúrate de que pronto_shared esté instalado:"
        echo "   cd ../pronto-libs && pip install -e ."
    fi
else
    echo "   ✅ Funciones de área ya aplicadas."
fi

# Verificar si existen áreas
echo ""
echo "📋 Paso 2: Verificando áreas existentes..."

AREA_COUNT=$(docker exec pronto-postgres psql -U pronto -d pronto -tAc "SELECT COUNT(*) FROM pronto_areas;" 2>/dev/null || echo "0")

if [ "$AREA_COUNT" -gt 0 ]; then
    echo "   ⚠️  Ya existen $AREA_COUNT áreas."
    echo "   ¿Sobreescribir áreas existentes? (s/N)"
    read -r OVERWRITE_AREA
    
    if [[ "$OVERWRITE_AREA" =~ ^[sS]$ ]]; then
        echo "   ⚠️  Sobreescritendo áreas..."
        docker exec pronto-postgres psql -U pronto -d pronto -c "TRUNCATE TABLE pronto_areas CASCADE;"
        echo "   ✅ Áreas eliminadas. Continuando con inicialización..."
    else
        echo "   ℹ️  Manteniendo áreas existentes. Saliendo."
        exit 0
    fi
else
    echo "   ✅ No existen áreas. Continuando..."
fi

echo ""
echo "📋 Paso 3: Creando áreas por defecto..."

# Crear Terraza (T - mesas 01-05)
TERRAZA_ID=$(docker exec pronto-postgres psql -U pronto -d pronto -tAc "SELECT create_area('Terraza', 'Área exterior al aire libre', '#4CAF50', 'T', '/assets/cafeteria/area-terraza.png', TRUE);" 2>/dev/null)
echo "   ✅ Terraza creada (ID: $TERRAZA_ID)"

# Crear Interior (I - mesas 11-20)
INTERIOR_ID=$(docker exec pronto-postgres psql -U pronto -d pronto -tAc "SELECT create_area('Interior', 'Área interior del restaurante', '#2196F3', 'I', '/assets/cafeteria/area-interior.png', TRUE);" 2>/dev/null)
echo "   ✅ Interior creada (ID: $INTERIOR_ID)"

# Crear Bar (B - mesas 01-05)
BAR_ID=$(docker exec pronto-postgres psql -U pronto -d pronto -tAc "SELECT create_area('Bar', 'Zona de bebidas', '#FF9800', 'B', '/assets/cafeteria/area-bar.png', TRUE);" 2>/dev/null)
echo "   ✅ Bar creada (ID: $BAR_ID)"

echo ""
echo "📋 Paso 4: Asignando mesas a sus áreas..."

# Asignar Terraza: T-M01 a T-M05 (y B-M01 a B-M05)
echo "   Asignando mesas T-M01 a T-M05 a Terraza..."
docker exec pronto-postgres psql -U pronto -d pronto -tAc "SELECT assign_tables_to_area_by_prefix('T', $TERRAZA_ID);" 2>/dev/null
echo "   Asignando mesas B-M01 a B-M05 a Terraza..."
docker exec pronto-postgres psql -U pronto -d pronto -tAc "SELECT assign_tables_to_area_by_prefix('B', $TERRAZA_ID);" 2>/dev/null
TERRAZA_COUNT=$(docker exec pronto-postgres psql -U pronto -d pronto -tAc "SELECT assign_tables_to_area_by_prefix('T', $TERRAZA_ID);" 2>/dev/null)
echo "   ✅ Terraza: $TERRAZA_COUNT mesas asignadas"

# Asignar Interior: I-M11 a I-M20
echo "   Asignando mesas I-M11 a I-M20 a Interior..."
INTERIOR_COUNT=$(docker exec pronto-postgres psql -U pronto -d pronto -tAc "SELECT assign_tables_to_area_by_prefix('I', $INTERIOR_ID);" 2>/dev/null)
echo "   ✅ Interior: $INTERIOR_COUNT mesas asignadas"

# Asignar Bar: T-M01 a T-M05
echo "   Asignando mesas T-M01 a T-M05 a Bar..."
BAR_COUNT=$(docker exec pronto-postgres psql -U pronto -d pronto -tAc "SELECT assign_tables_to_area_by_prefix('T', $BAR_ID);" 2>/dev/null)
echo "   ✅ Bar: $BAR_COUNT mesas asignadas"

echo ""
echo "📋 Paso 5: Verificando asignaciones..."

echo "   Mesas por área:"
docker exec pronto-postgres psql -U pronto -d pronto -c "
SELECT 
    a.name AS area_name,
    COUNT(t.id) AS table_count
FROM pronto_areas a
LEFT JOIN pronto_tables t ON t.area_id = a.id
WHERE a.is_active = true
GROUP BY a.id, a.name
ORDER BY a.prefix;
" 2>&1

echo ""
echo "📋 Paso 6: Estadísticas finales"

echo "   Resumen del sistema:"
docker exec pronto-postgres psql -U pronto -d pronto -c "
SELECT 
    'Áreas Activas' AS metrica, COUNT(*) AS valor 
FROM pronto_areas WHERE is_active = TRUE
UNION ALL
SELECT 'Mesas Activas' AS metrica, COUNT(*) FILTER(is_active = TRUE) AS valor 
FROM pronto_tables
UNION ALL
SELECT 'Mesas con Área' AS metrica, COUNT(*) FILTER(area_id IS NOT NULL AND is_active = TRUE) AS valor 
FROM pronto_tables
UNION ALL
SELECT 'Mesas sin Área' AS metrica, COUNT(*) FILTER(area_id IS NULL AND is_active = TRUE) AS valor 
FROM pronto_tables;
" 2>&1

echo ""
echo "✅ Inicialización de áreas completada."
echo ""
echo "💡 Para administrar áreas, usa:"
echo "   - docker exec pronto-postgres psql -U pronto -d pronto -c \"SELECT * FROM pronto_areas;\""
echo "   - docker exec pronto-postgres psql -U pronto -d pronto -c \"SELECT get_tables_by_area(area_id);\""
echo "   - docker exec pronto-postgres psql -U pronto -d pronto -c \"SELECT get_area_statistics();\""
echo ""

