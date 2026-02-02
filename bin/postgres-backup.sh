#!/bin/bash
# Backup PostgreSQL local database

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

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Generate backup filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/pronto_backup_${TIMESTAMP}.sql"

echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║   💾 BACKUP DE POSTGRESQL 💾                    ║"
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
echo "   Base de datos: ${POSTGRES_DB}"
echo "   Usuario: ${POSTGRES_USER}"
echo "   Archivo: ${BACKUP_FILE}"
echo ""

# Create backup
echo "💾 Creando backup..."
docker exec pronto-postgres pg_dump -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" --clean --if-exists > "${BACKUP_FILE}"

if [ $? -eq 0 ]; then
    echo "✅ Backup completado exitosamente"
    echo ""
    echo "📦 Archivo creado:"
    echo "   ${BACKUP_FILE}"
    echo ""
    echo "📊 Tamaño:"
    ls -lh "${BACKUP_FILE}" | awk '{print "   " $5}'
    echo ""
    echo "Para restaurar:"
    echo "  bash bin/postgres-restore.sh ${BACKUP_FILE}"
else
    echo "❌ Error al crear backup"
    exit 1
fi

# Clean old backups (keep last 5)
echo ""
echo "🧹 Limpiando backups antiguos (manteniendo últimos 5)..."
cd "${BACKUP_DIR}"
ls -t pronto_backup_*.sql | tail -n +6 | xargs -r rm -f
echo "✅ Limpieza completada"
