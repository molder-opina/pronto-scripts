#!/bin/bash
# Script para ver los empleados en la base de datos

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/lib/docker_runtime.sh
source "${SCRIPT_DIR}/lib/docker_runtime.sh"

echo "======================================================"
echo "  DIAGNÓSTICO - Empleados en la Base de Datos"
echo "======================================================"
echo ""

# Verificar si los contenedores están corriendo
if ! docker-compose ps | grep -q "Up"; then
    echo "⚠️  Los contenedores no están corriendo"
    echo "   Ejecuta: bash bin/up.sh"
    exit 1
fi

echo "Consultando empleados en la base de datos..."
echo ""

docker-compose exec -T shared-db psql -U pronto -d pronto_db -c "
SELECT
    id,
    substring(email_encrypted, 1, 30) as email_encrypted_preview,
    substring(email_hash, 1, 20) as email_hash_preview,
    role,
    is_active,
    created_at
FROM employees
ORDER BY id;
" 2>/dev/null || echo "❌ No se pudo conectar a la base de datos"

echo ""
echo "Para desencriptar un email específico, usa el script Python de prueba"
echo ""
