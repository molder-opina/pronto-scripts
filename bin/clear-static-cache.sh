#!/usr/bin/env bash
# Script para limpiar el caché de nginx después de actualizar imágenes
#
# IMPORTANTE: Este script es SOLO para el servidor Linux
#             En Linux, nginx está instalado localmente en el sistema
#             En Mac, nginx corre como contenedor Docker - usa bin/mac/clear-static-cache.sh

set -euo pipefail

echo "=========================================="
echo "  Limpieza de Caché de Nginx (LINUX)"
echo "=========================================="
echo ""

# Verificar si nginx está corriendo localmente
if ! command -v nginx >/dev/null 2>&1; then
  echo "❌ Error: nginx no está instalado o no está en el PATH"
  echo "ℹ️  Si estás en Mac, usa: bin/mac/clear-static-cache.sh"
  exit 1
fi

# Limpiar caché de nginx si existe
NGINX_CACHE_DIR="/var/cache/nginx"
if [[ -d "${NGINX_CACHE_DIR}" ]]; then
  echo ">> Limpiando caché de nginx en ${NGINX_CACHE_DIR}..."
  sudo rm -rf "${NGINX_CACHE_DIR}"/*
  echo "   ✓ Caché de nginx limpiado"
else
  echo "ℹ️  No se encontró directorio de caché de nginx"
fi

# Recargar configuración de nginx
echo ">> Recargando configuración de nginx..."
sudo nginx -t && sudo nginx -s reload
echo "   ✓ Nginx recargado"

echo ""
echo "✅ Caché limpiado exitosamente"
echo ""
echo "💡 Recuerda también limpiar el caché del navegador:"
echo "   - Chrome/Edge: Ctrl+Shift+R (Windows/Linux) o Cmd+Shift+R (Mac)"
echo "   - Firefox: Ctrl+F5 (Windows/Linux) o Cmd+Shift+R (Mac)"
echo ""
