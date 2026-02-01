#!/usr/bin/env bash
# bin/lib/cleanup_helpers.sh
# Helper functions for cleaning up containers and images

# Check if a container exists by name pattern
exists_container_by_name() {
  local pattern="$1"
  [[ -z "${pattern}" ]] && return 1
  "${CONTAINER_CLI}" ps -a --format '{{.Names}}' --filter "name=${pattern}" | grep -Eq '.+'
}

# Kill and remove containers matching a name pattern
kill_and_rm_by_name() {
  local pattern="$1"
  if [[ -z "${pattern}" ]]; then
    echo "⚠️  Patron vacío en kill_and_rm_by_name; omitiendo por seguridad." >&2
    return 0
  fi
  # Lista contenedores que matchean (por nombre) y opera sobre cada uno
  NAMES=()
  while IFS= read -r name; do
    [[ -n "${name}" ]] && NAMES+=("${name}")
  done < <("${CONTAINER_CLI}" ps -a --format '{{.Names}}' --filter "name=${pattern}")
  [[ ${#NAMES[@]} -eq 0 ]] && return 0

  for name in "${NAMES[@]}"; do
    # best effort stop -> kill -> rm -f
    "${CONTAINER_CLI}" stop -t 10 "$name" > /dev/null 2>&1 || true
    "${CONTAINER_CLI}" kill "$name"          > /dev/null 2>&1 || true
    "${CONTAINER_CLI}" rm -f "$name"         > /dev/null 2>&1 || true
  done

  # Espera corta a que desaparezcan
  for _ in {1..20}; do
    exists_container_by_name "$pattern" || return 0
    sleep 0.5
  done

  # Un intento final
  NAMES2=()
  while IFS= read -r name; do
    [[ -n "${name}" ]] && NAMES2+=("${name}")
  done < <("${CONTAINER_CLI}" ps -a --format '{{.Names}}' --filter "name=${pattern}")
  for name in "${NAMES2[@]}"; do
    "${CONTAINER_CLI}" kill "$name"  > /dev/null 2>&1 || true
    "${CONTAINER_CLI}" rm -f "$name" > /dev/null 2>&1 || true
  done
}

# Clean up old images for specified services
cleanup_old_images() {
  local services=("$@")
  
  echo ">> Limpiando imágenes antiguas de Pronto..."

  # Detectar si usa podman o docker
  CONTAINER_RUNTIME="docker"
  if command -v podman > /dev/null 2>&1 && podman ps > /dev/null 2>&1; then
    CONTAINER_RUNTIME="podman"
  fi

  CONTAINER_RUNTIME_CMD=("${CONTAINER_RUNTIME}")
  if ! "${CONTAINER_RUNTIME_CMD[@]}" images > /dev/null 2>&1; then
    if command -v sudo > /dev/null 2>&1 && sudo -n "${CONTAINER_RUNTIME}" images > /dev/null 2>&1; then
      CONTAINER_RUNTIME_CMD=(sudo "${CONTAINER_RUNTIME}")
    else
      echo "⚠️  No se pudo acceder al runtime (${CONTAINER_RUNTIME}) para limpiar imágenes; omitiendo cleanup."
      CONTAINER_RUNTIME_CMD=()
    fi
  fi

  for service in "${services[@]}"; do
    # Buscar imágenes del servicio (solo servicios propios)
    if [[ "$service" == "client" || "$service" == "employee" ]]; then
      if [[ ${#CONTAINER_RUNTIME_CMD[@]} -eq 0 ]]; then
        continue
      fi
      OLD_IMAGES=()
      while IFS= read -r image; do
        [[ -n "${image}" ]] && OLD_IMAGES+=("${image}")
      done < <("${CONTAINER_RUNTIME_CMD[@]}" images --format '{{.Repository}}:{{.Tag}}' | grep "pronto-${service}" || true)
      if ((${#OLD_IMAGES[@]} > 0)); then
        for img in "${OLD_IMAGES[@]}"; do
          echo "   - Eliminando imagen: $img"
          "${CONTAINER_RUNTIME_CMD[@]}" rmi -f "$img" 2>/dev/null || true
        done
      fi
    fi
  done

  # Limpiar imágenes huérfanas y sin etiquetar
  echo ">> Limpiando imágenes huérfanas y sin etiquetar..."
  if [[ ${#CONTAINER_RUNTIME_CMD[@]} -gt 0 ]]; then
    "${CONTAINER_RUNTIME_CMD[@]}" image prune -f --filter "dangling=true" 2>/dev/null || true
  fi

  # Limpiar capas intermedias y cache de build (opcional pero recomendado)
  echo ">> Limpiando cache de build..."
  if [[ ${#CONTAINER_RUNTIME_CMD[@]} -gt 0 ]]; then
    echo "   (Skipped builder prune to keep cache)"
  fi
}
