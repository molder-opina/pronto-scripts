#!/bin/bash
# Script de rebuild para macOS
# Uso: bash rebuild.sh employee

set -e

SERVICE=${1:-employee}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
PRONTO_STATIC_DIR="${REPO_ROOT}/pronto-static"

echo "🔨 Compilando TypeScript..."
if command -v pnpm &> /dev/null; then
    pnpm -C "${PRONTO_STATIC_DIR}" build
else
    npm --prefix "${PRONTO_STATIC_DIR}" run build
fi


# Limpiar colas de notificaciones en Redis
if docker compose ps | grep -q redis; then
    echo "🧹 Limpiando colas de notificaciones (Redis)..."
    docker compose exec -T redis redis-cli FLUSHDB || echo "⚠️ No se pudo limpiar Redis (¿contenedor detenido?)"
fi

echo "🐳 Reconstruyendo servicio $SERVICE..."
cd "${REPO_ROOT}"
docker compose build "$SERVICE"

echo "🔄 Reiniciando servicio $SERVICE..."
docker compose up -d "$SERVICE"

echo "✅ Rebuild completado para $SERVICE"
echo "📋 Ver logs: docker logs -f pronto-$SERVICE"
