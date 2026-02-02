#!/usr/bin/env bash
# Script para sincronizar imágenes de productos generadas con IA
# al contenedor static de nginx

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Cargar variables de entorno
ENV_FILE="${PROJECT_ROOT}/.env"
if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=../.env
  source "${ENV_FILE}"
  set +a
fi

RESTAURANT_NAME="${RESTAURANT_NAME:-cafeteria-test}"
SOURCE_DIR="${PROJECT_ROOT}/build/static_content/assets/${RESTAURANT_NAME}/products"
DEST_NGINX="/var/www/pronto-static/assets/${RESTAURANT_NAME}/products"

echo "=========================================="
echo "  Sincronización de Imágenes de Productos"
echo "=========================================="
echo ""
echo "Restaurante: ${RESTAURANT_NAME}"
echo "Origen:      ${SOURCE_DIR}"
echo "Destino:     ${DEST_NGINX}"
echo ""

# Verificar que exista el directorio de origen
if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "❌ Error: No existe el directorio de origen: ${SOURCE_DIR}"
  echo ""
  echo "Primero genera las imágenes con:"
  echo "  python scripts/generate_product_images.py"
  exit 1
fi

# Contar imágenes en origen
IMAGE_COUNT=$(find "${SOURCE_DIR}" -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" | wc -l | tr -d ' ')

if [[ "${IMAGE_COUNT}" -eq 0 ]]; then
  echo "⚠️  Advertencia: No se encontraron imágenes en ${SOURCE_DIR}"
  echo ""
  echo "Genera las imágenes primero con:"
  echo "  python scripts/generate_product_images.py"
  exit 0
fi

echo "📦 Encontradas ${IMAGE_COUNT} imágenes para sincronizar"
echo ""

# Crear directorio de destino si no existe
if [[ -d "${DEST_NGINX}" ]]; then
  echo ">> Directorio de destino existe: ${DEST_NGINX}"
else
  echo ">> Creando directorio de destino: ${DEST_NGINX}"
  sudo mkdir -p "${DEST_NGINX}"
fi

# Sincronizar imágenes
echo ">> Sincronizando imágenes..."
if command -v rsync >/dev/null 2>&1; then
  sudo rsync -av --exclude='.DS_Store' "${SOURCE_DIR}/" "${DEST_NGINX}/"
else
  sudo cp -av "${SOURCE_DIR}/." "${DEST_NGINX}/"
fi

# Ajustar permisos
echo ">> Ajustando permisos..."
sudo chown -R www-data:www-data "${DEST_NGINX}" 2>/dev/null || sudo chown -R nginx:nginx "${DEST_NGINX}" 2>/dev/null || true
sudo chmod -R 755 "${DEST_NGINX}"

echo ""
echo "✅ Sincronización completada"
echo ""
echo "📊 Resumen:"
echo "   - Imágenes sincronizadas: ${IMAGE_COUNT}"
echo "   - Ubicación: ${DEST_NGINX}"
echo ""
echo "🌐 Las imágenes están disponibles en:"
echo "   https://pronto-admin.molderx.xyz/assets/${RESTAURANT_NAME}/products/"
echo ""
echo "💡 Recuerda reconstruir el contenedor static si usas Docker:"
echo "   bin/rebuild.sh static"
echo ""
