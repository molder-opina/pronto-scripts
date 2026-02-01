#!/bin/bash
# Rebuild PostgreSQL local container for Pronto

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"
REMOVE_DATA=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --remove-data)
            REMOVE_DATA=true
            shift
            ;;
        --help|-h)
            echo "Uso: $(basename "$0") [opciones]"
            echo ""
            echo "Reconstruye el contenedor de PostgreSQL local."
            echo ""
            echo "Opciones:"
            echo "  --remove-data    Elimina también el volumen con todos los datos"
            echo "  -h, --help      Muestra esta ayuda"
            echo ""
            echo "Ejemplos:"
            echo "  $(basename "$0")                # Reconstruye manteniendo datos"
            echo "  $(basename "$0") --remove-data  # Reconstruye eliminando datos"
            exit 0
            ;;
        *)
            echo "Error: Opción desconocida '$1'"
            echo "Usa --help para ver las opciones"
            exit 1
            ;;
    esac
done

echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║   🔄 RECONSTRUYENDO POSTGRESQL LOCAL 🔄               ║"
echo "║                                                       ║"
echo "╚═════════════════════════════════════════════════════╝"
echo ""

if [ "$REMOVE_DATA" = true ]; then
    echo "⚠️  ATENCIÓN: Se eliminarán TODOS los datos de PostgreSQL"
    echo ""
    read -p "¿Estás seguro? (Escribe 'SÍ' para confirmar): " -r
    echo
    if [[ ! $REPLY == "SÍ" ]]; then
        echo "❌ Cancelado"
        exit 1
    fi
fi

# Stop and remove container
echo "🛑 Deteniendo y eliminando contenedor pronto-postgres..."
docker compose -f "${COMPOSE_FILE}" stop postgres 2>/dev/null || true
docker compose -f "${COMPOSE_FILE}" rm -f postgres 2>/dev/null || true

# Remove volume if requested
if [ "$REMOVE_DATA" = true ]; then
    echo "🗑️  Eliminando volumen postgres_data..."
    docker volume rm pronto-postgres_data 2>/dev/null || echo "   Volumen ya eliminado o no existe"
fi

# Rebuild and start
echo ""
echo "🔨 Reconstruyendo imagen de PostgreSQL..."
docker compose -f "${COMPOSE_FILE}" build postgres

echo ""
echo "🚀 Iniciando contenedor..."
docker compose -f "${COMPOSE_FILE}" up -d postgres

# Wait for PostgreSQL to be ready
echo ""
echo "⏳ Esperando a que PostgreSQL esté listo..."
max_attempts=30
attempt=0

while [[ $attempt -lt $max_attempts ]]; do
    if docker exec pronto-postgres pg_isready -U "${POSTGRES_USER:-pronto}" > /dev/null 2>&1; then
        echo "✅ PostgreSQL está listo"
        break
    fi
    echo "   Esperando... (intento $((attempt + 1))/${max_attempts})"
    sleep 2
    ((attempt++))
done

if [[ $attempt -eq $max_attempts ]]; then
    echo "❌ Error: PostgreSQL no inició correctamente"
    exit 1
fi

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║   ✅ POSTGRESQL RECONSTRUIDO                       ║"
echo "║                                                       ║"
echo "╚═════════════════════════════════════════════════════╝"
echo ""
echo "Para inicializar la base de datos:"
echo "  bash bin/init/postgres.sh"
echo ""
