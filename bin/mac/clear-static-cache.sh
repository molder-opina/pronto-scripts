#!/usr/bin/env bash
# Script para limpiar el caché del contenedor nginx en macOS
#
# IMPORTANTE: Este script es SOLO para macOS con Docker Desktop
#             En Mac, nginx corre como contenedor Docker (servicio 'static')
#             En Linux, usa: bin/clear-static-cache.sh (nginx instalado localmente)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENV_FILE="${PROJECT_ROOT}/.env"

# Load environment variables
set -a
# shellcheck disable=SC1090
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-pronto}"
STATIC_CONTAINER="${COMPOSE_PROJECT_NAME}-static"
COMPOSE_CMD=(docker compose -f "${PROJECT_ROOT}/docker-compose.yml" -p "${COMPOSE_PROJECT_NAME}" --env-file "${ENV_FILE}")

echo "=========================================="
echo "  Limpieza de Caché de Nginx (macOS)"
echo "=========================================="
echo ""

# Verificar si el contenedor está corriendo
if ! docker ps --format '{{.Names}}' | grep -q "^${STATIC_CONTAINER}$"; then
  echo "⚠️  Advertencia: El contenedor ${STATIC_CONTAINER} no está corriendo"
  echo "   Iniciándolo primero..."
  "${COMPOSE_CMD[@]}" up -d static
  sleep 2
fi

# Limpiar caché de nginx dentro del contenedor
echo ">> Limpiando caché del contenedor nginx..."
docker exec "${STATIC_CONTAINER}" sh -c 'rm -rf /var/cache/nginx/* 2>/dev/null || true'
echo "   ✓ Caché limpiado"

# Recargar configuración de nginx
echo ">> Recargando configuración de nginx..."
docker exec "${STATIC_CONTAINER}" nginx -s reload
echo "   ✓ Nginx recargado"

echo ""
echo "✅ Caché limpiado exitosamente"
echo ""
echo "💡 Recuerda también limpiar el caché del navegador:"
echo "   - Chrome/Edge: Cmd+Shift+R"
echo "   - Firefox: Cmd+Shift+R"
echo ""
echo "📊 Estado del contenedor:"
docker ps --filter "name=${STATIC_CONTAINER}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
