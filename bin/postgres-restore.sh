#!/bin/bash
# Restore PostgreSQL local database from backup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backups/postgres"

# Load environment variables
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${PROJECT_ROOT}/.env"
    set +a
fi

POSTGRES_USER="${POSTGRES_USER:-pronto}"
POSTGRES_DB="${POSTGRES_DB:-pronto}"

# Check if backup file is provided
if [ $# -eq 0 ]; then
    echo "📂 Backups disponibles:"
    echo ""
    if [[ -d "${BACKUP_DIR}" ]]; then
        ls -lh "${BACKUP_DIR}"/pronto_backup_*.sql 2>/dev/null || echo "   No hay backups disponibles"
        echo ""
        echo "Uso: $(basename "$0") <archivo_backup.sql>"
        echo "Ejemplo: $(basename "$0") ${BACKUP_DIR}/pronto_backup_20250115_120000.sql"
    else
        echo "   Directorio de backups no existe"
    fi
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "${BACKUP_FILE}" ]; then
    echo "❌ Error: El archivo de backup no existe: ${BACKUP_FILE}"
    exit 1
fi

echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║   📥 RESTAURANDO POSTGRESQL 📥               ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# Check if container is running
if ! docker ps --format "{{.Names}}" | grep -q pronto-postgres; then
    echo "❌ Error: El contenedor pronto-postgres no está corriendo"
    echo ""
    echo "Para iniciar:"
    echo "  bash bin/postgres-up.sh"
    exit 1
fi

echo "📋 Información:"
echo "   Archivo: ${BACKUP_FILE}"
echo "   Base de datos: ${POSTGRES_DB}"
echo "   Usuario: ${POSTGRES_USER}"
echo ""

# Confirm restore
echo "⚠️  ADVERTENCIA: Esto sobrescribirá toda la base de datos"
echo ""
read -p "¿Estás seguro? (Escribe 'SÍ' para confirmar): " -r
echo
if [[ ! $REPLY == "SÍ" ]]; then
    echo "❌ Cancelado"
    exit 1
fi

# Restore backup
echo ""
echo "📥 Restaurando backup..."
docker exec -i pronto-postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" < "${BACKUP_FILE}"

if [ $? -eq 0 ]; then
    echo "✅ Backup restaurado exitosamente"
    echo ""
    echo "📊 Verificando tablas:"
    docker exec pronto-postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "\dt" 2>/dev/null || echo "   No hay tablas disponibles"
    echo ""
    echo "Puede que necesites reiniciar las aplicaciones:"
    echo "  docker compose restart client employee"
else
    echo "❌ Error al restaurar backup"
    exit 1
fi
