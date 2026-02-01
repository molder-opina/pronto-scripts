#!/bin/bash
# Script de rebuild para macOS
# Uso: bash rebuild.sh employee

set -e

SERVICE=${1:-employee}

echo "🔨 Compilando TypeScript..."
cd /Users/molder/Library/CloudStorage/OneDrive-Personal/cochinadas/freelance/pronto-app
npm run build


# Limpiar colas de notificaciones en Redis
if docker compose ps | grep -q redis; then
    echo "🧹 Limpiando colas de notificaciones (Redis)..."
    docker compose exec -T redis redis-cli FLUSHDB || echo "⚠️ No se pudo limpiar Redis (¿contenedor detenido?)"
fi

echo "🐳 Reconstruyendo servicio $SERVICE..."
docker compose build $SERVICE

echo "🔄 Reiniciando servicio $SERVICE..."
docker compose up -d $SERVICE

echo "✅ Rebuild completado para $SERVICE"
echo "📋 Ver logs: docker logs -f pronto-$SERVICE"
