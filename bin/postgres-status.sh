#!/bin/bash
# Status del servicio PostgreSQL local

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "╔═════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║   📊 ESTADO DE POSTGRESQL LOCAL 📊           ║"
echo "║                                                       ║"
echo "╚═════════════════════════════════════════════════════╝"
echo ""

# Check container status
if docker ps --format "{{.Names}}" | grep -q pronto-postgres; then
    echo "✅ Contenedor: CORRIENDO"
    echo ""

    # Show container info
    docker ps --format "   Name: {{.Names}}\n   Status: {{.Status}}\n   Ports: {{.Ports}}" | grep pronto-postgres

    echo ""
    echo "📊 Uso de recursos:"
    docker stats pronto-postgres --no-stream --format "   CPU: {{.CPUPerc}}\n   Mem: {{.MemUsage}}"

    echo ""
    echo "📦 Volumen:"
    docker volume inspect pronto_postgres_data --format '{{.Mountpoint}}' 2>/dev/null || echo "   No encontrado"

    echo ""
    echo "💾 Backups disponibles:"
    if [[ -d "${PROJECT_ROOT}/backups/postgres" ]]; then
        ls -lh "${PROJECT_ROOT}/backups/postgres"/pronto_backup_*.sql 2>/dev/null || echo "   No hay backups"
    else
        echo "   Directorio de backups no existe"
    fi
else
    echo "❌ Contenedor: NO CORRIENDO"
    echo ""
    echo "Para iniciar:"
    echo "  bash bin/postgres-up.sh"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
