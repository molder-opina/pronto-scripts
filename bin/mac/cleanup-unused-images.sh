#!/usr/bin/env bash
# bin/mac/cleanup-unused-images.sh — Elimina imágenes no utilizadas del proyecto Pronto
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENV_FILE="${PROJECT_ROOT}/config/general.env"
SECRETS_FILE="${PROJECT_ROOT}/config/secrets.env"

# Load environment variables
set -a
# shellcheck source=../../config/general.env
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"
# shellcheck source=../../config/secrets.env
[[ -f "${SECRETS_FILE}" ]] && source "${SECRETS_FILE}"
set +a

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-pronto}"

echo "=========================================="
echo "  Limpieza de Imágenes No Utilizadas"
echo "=========================================="
echo ""
echo "Proyecto: ${COMPOSE_PROJECT_NAME}"
echo ""

# Get all images related to this project
PROJECT_IMAGES=(
  "${CLIENT_IMAGE_REPO:-pronto-client}"
  "${EMPLOYEE_IMAGE_REPO:-pronto-employee}"
  "${STATIC_IMAGE_REPO:-pronto-static}"
)

# Get all running/stopped containers for this project
echo ">> Identificando contenedores del proyecto..."
PROJECT_CONTAINERS=()
while IFS= read -r line; do
  [[ -n "$line" ]] && PROJECT_CONTAINERS+=("$line")
done < <(docker ps -a --filter "name=${COMPOSE_PROJECT_NAME}" --format "{{.ID}} {{.Image}} {{.Names}}" 2>/dev/null || true)

# Extract image IDs that are currently in use
USED_IMAGE_IDS=()
for container_info in "${PROJECT_CONTAINERS[@]}"; do
  if [[ -n "${container_info}" ]]; then
    container_id=$(echo "${container_info}" | awk '{print $1}')
    image_id=$(docker inspect --format '{{.Image}}' "${container_id}" 2>/dev/null || true)
    if [[ -n "${image_id}" ]]; then
      # Remove 'sha256:' prefix if present
      image_id="${image_id#sha256:}"
      USED_IMAGE_IDS+=("${image_id}")
    fi
  fi
done

echo "   - Contenedores encontrados: ${#PROJECT_CONTAINERS[@]}"
echo "   - Imágenes en uso: ${#USED_IMAGE_IDS[@]}"
echo ""

# Find all images for this project
echo ">> Buscando imágenes del proyecto..."
UNUSED_IMAGES=()
TOTAL_IMAGES=0

for repo in "${PROJECT_IMAGES[@]}"; do
  echo "   - Buscando imágenes de: ${repo}"
  REPO_IMAGES=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && REPO_IMAGES+=("$line")
  done < <(docker images "${repo}" --format "{{.ID}} {{.Repository}}:{{.Tag}}" 2>/dev/null || true)

  if [[ ${#REPO_IMAGES[@]} -eq 0 ]]; then
    echo "     ℹ️  No se encontraron imágenes de ${repo}"
    continue
  fi

  for image_info in "${REPO_IMAGES[@]}"; do
    if [[ -n "${image_info}" ]]; then
      image_id=$(echo "${image_info}" | awk '{print $1}')
      image_name=$(echo "${image_info}" | awk '{print $2}')

      # Remove 'sha256:' prefix if present
      image_id="${image_id#sha256:}"

      TOTAL_IMAGES=$((TOTAL_IMAGES + 1))

      # Check if this image is being used
      IS_USED=0
      for used_id in "${USED_IMAGE_IDS[@]}"; do
        if [[ "${image_id}" == "${used_id}" ]]; then
          IS_USED=1
          break
        fi
      done

      if [[ ${IS_USED} -eq 0 ]]; then
        # Also check if any container is using this image
        CONTAINERS_USING=$(docker ps -a --filter "ancestor=${image_name}" --format "{{.ID}}" 2>/dev/null | wc -l | tr -d ' ')
        if [[ "${CONTAINERS_USING}" == "0" ]]; then
          UNUSED_IMAGES+=("${image_name}")
          echo "     ⚠️  No utilizada: ${image_name}"
        else
          echo "     ✓ En uso: ${image_name} (${CONTAINERS_USING} contenedor(es))"
        fi
      else
        echo "     ✓ En uso: ${image_name}"
      fi
    fi
  done
done

echo ""
echo "📊 Resumen:"
echo "   - Total de imágenes encontradas: ${TOTAL_IMAGES}"
echo "   - Imágenes no utilizadas: ${#UNUSED_IMAGES[@]}"
echo ""

if [[ ${#UNUSED_IMAGES[@]} -eq 0 ]]; then
  echo "✅ No hay imágenes no utilizadas para eliminar"
  echo ""
  exit 0
fi

echo "🗑️  Imágenes que se eliminarán:"
for img in "${UNUSED_IMAGES[@]}"; do
  echo "   - ${img}"
done
echo ""

# Ask for confirmation
read -p "¿Deseas eliminar estas ${#UNUSED_IMAGES[@]} imágenes? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
  echo "❌ Operación cancelada"
  exit 0
fi

echo ""
echo ">> Eliminando imágenes no utilizadas..."
DELETED=0
FAILED=0

for img in "${UNUSED_IMAGES[@]}"; do
  if docker rmi -f "${img}" 2>/dev/null; then
    echo "   ✅ Eliminada: ${img}"
    DELETED=$((DELETED + 1))
  else
    echo "   ❌ Error eliminando: ${img}"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "=========================================="
echo "  Limpieza Completada"
echo "=========================================="
echo "   - Eliminadas: ${DELETED}"
echo "   - Errores: ${FAILED}"
echo ""

# Also clean up dangling images
echo ">> Limpiando imágenes huérfanas (dangling)..."
DANGLING_COUNT=$(docker images -f "dangling=true" -q 2>/dev/null | wc -l | tr -d ' ')
if [[ "${DANGLING_COUNT}" -gt 0 ]]; then
  docker image prune -f 2>/dev/null || true
  echo "   ✅ ${DANGLING_COUNT} imágenes huérfanas eliminadas"
else
  echo "   ℹ️  No hay imágenes huérfanas"
fi

echo ""
echo "✅ Limpieza finalizada"
echo ""
