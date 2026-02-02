#!/usr/bin/env bash
# bin/lib/static_helpers.sh
# Helper functions for static content synchronization

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
PRONTO_STATIC_DIR="${PRONTO_STATIC_DIR:-${PROJECT_ROOT}/pronto-static/src/static_content}"
PRONTO_STATIC_ASSETS_DIR="${PRONTO_STATIC_DIR}/assets"

slugify() {
  local input="${1:-}"
  input="$(echo "${input}" | tr '[:upper:]' '[:lower:]')"
  input="$(echo "${input}" | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"
  if [[ -z "${input}" ]]; then
    input="restaurant"
  fi
  echo "${input}"
}

ensure_static_placeholder() {
    local static_root="/var/www/pronto-static"
  local restaurant_name="${RESTAURANT_NAME:-cafeteria-test}"
  local slug
  slug="$(slugify "${restaurant_name}")"

  local placeholder_path="${static_root}/assets/${slug}/icons/placeholder.png"
  if [[ -f "${placeholder_path}" ]]; then
    return 0
  fi

  echo ">> Creando placeholder de imágenes faltantes (${placeholder_path})..."
  sudo install -d "$(dirname "${placeholder_path}")"

  # 1x1 PNG transparente (evita dependencias tipo Pillow/ImageMagick).
  local png_b64="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMB/6X+6QAAAABJRU5ErkJggg=="
  echo "${png_b64}" | base64 -d | sudo tee "${placeholder_path}" > /dev/null
  sudo chmod 0644 "${placeholder_path}" || true
  sudo chmod -R a+rX "${static_root}/assets/${slug}" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# validate_static_pod - Valida que el pod/contenedor de contenido estático esté activo
# ═══════════════════════════════════════════════════════════════════════════════
# Verifica:
#   1. En macOS: Que el contenedor 'pronto-static' esté ejecutándose
#   2. En Linux: Que nginx esté configurado y sirviendo en puerto 9088
#   3. Que el contenido estático sea accesible vía HTTP
#
# Retorna:
#   0 - El servidor estático está disponible
#   1 - El servidor estático NO está disponible (solo advertencia, no bloquea)
# ═══════════════════════════════════════════════════════════════════════════════
validate_static_pod() {
  local os_type
  os_type="$(uname -s)"
  
  local static_url="${STATIC_HOST_URL:-http://localhost:9088}"
  local project_prefix="${PROJECT_PREFIX:-pronto}"
  local static_container="${project_prefix}-static"
  
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║          Validación de Servidor de Contenido Estático               ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo ""
  
  # Verificar según el sistema operativo
  case "$os_type" in
    Darwin)
      echo ">> Sistema: macOS (desarrollo)"
      echo ">> Verificando pod static: ${static_container}"
      
      # Verificar si el contenedor existe y está ejecutándose
      if command -v docker &> /dev/null; then
        if docker ps --format '{{.Names}}' | grep -q "^${static_container}$"; then
          echo "   ✅ Contenedor '${static_container}' está ejecutándose"
        else
          echo "   ⚠️  ADVERTENCIA: Contenedor '${static_container}' NO está ejecutándose"
          echo "      El contenido estático podría no estar disponible"
          echo "      Ejecuta: docker-compose up -d static"
          return 1
        fi
      else
        echo "   ⚠️  Docker no está disponible, no se puede verificar el pod static"
        return 1
      fi
      ;;
      
    Linux)
      echo ">> Sistema: Linux (producción)"
      echo ">> Verificando nginx en puerto 9088"
      
      # Verificar si nginx está ejecutándose
      if pgrep -x nginx > /dev/null 2>&1; then
        echo "   ✅ Nginx está ejecutándose"
      else
        echo "   ⚠️  ADVERTENCIA: Nginx NO está ejecutándose"
        echo "      El contenido estático podría no estar disponible"
        return 1
      fi
      ;;
      
    *)
      echo ">> Sistema: ${os_type} (no reconocido)"
      echo "   ⚠️  No se puede validar el servidor estático en este sistema"
      return 1
      ;;
  esac
  
  # Verificar accesibilidad HTTP del servidor estático
  echo ">> Verificando accesibilidad: ${static_url}"
  
  if command -v curl &> /dev/null; then
    local http_code
    http_code=$(curl -s -o /dev/null -w '%{http_code}' "${static_url}/" 2>/dev/null || echo "000")
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "301" ]] || [[ "$http_code" == "302" ]]; then
      echo "   ✅ Servidor estático accesible (HTTP ${http_code})"
    else
      echo "   ⚠️  ADVERTENCIA: Servidor estático no responde correctamente (HTTP ${http_code})"
      echo "      URL: ${static_url}"
      return 1
    fi
  else
    echo "   ⚠️  curl no disponible, no se puede verificar accesibilidad HTTP"
  fi
  
  # Verificar un archivo específico (CSS de notificaciones)
  if command -v curl &> /dev/null; then
    local test_file="${static_url}/assets/css/notifications.css"
    local file_code
    file_code=$(curl -s -o /dev/null -w '%{http_code}' "${test_file}" 2>/dev/null || echo "000")
    
    if [[ "$file_code" == "200" ]]; then
      echo "   ✅ Contenido estático accesible (assets/css/notifications.css)"
    else
      echo "   ⚠️  ADVERTENCIA: Archivo de prueba no accesible (HTTP ${file_code})"
      echo "      URL: ${test_file}"
      echo "      Esto podría indicar que el contenido no está sincronizado"
    fi
  fi
  
  echo ""
  echo "✅ Validación completada"
  echo "   URL configurada: ${static_url}"
  echo ""
  
  return 0
}

sync_static_content() {
    local services=("$@")
    local sync_static=0

    for service in "${services[@]}"; do
        case "$service" in
            client|employee|static) sync_static=1 ;;
        esac
    done

    if [[ $sync_static -eq 0 ]]; then
        echo ">> Omitiendo sync de estáticos (no aplica a los servicios solicitados)."
        return 0
    fi

    local os_type
    os_type="$(uname -s)"
    local project_prefix="${PROJECT_PREFIX:-pronto}"
    local static_container="${project_prefix}-static"

    # Cargar variables de configuración del servidor de contenido estático
    local nginx_host="${NGINX_HOST:-localhost}"
    local nginx_port="${NGINX_PORT:-9088}"
    local nginx_prefix="${NGINX_PREFIX:-}"
    local static_content_root="/var/www/pronto-static"

    case "$os_type" in
        Darwin)
            echo ">> Sincronizando contenido estático al pod '${static_container}' (macOS)..."

            # Verificar si el contenedor existe
            if ! docker ps --format '{{.Names}}' | grep -q "^${static_container}$"; then
                echo "   ⚠️  Contenedor '${static_container}' no está ejecutándose"
                echo "      Ejecuta: docker-compose up -d static"
                return 1
            fi

            # Crear directorios en el contenedor
            docker exec "$static_container" mkdir -p /usr/share/nginx/html/assets/js 2>/dev/null || true
            docker exec "$static_container" mkdir -p /usr/share/nginx/html/assets/css 2>/dev/null || true
            docker exec "$static_container" mkdir -p /usr/share/nginx/html/assets/pronto/branding 2>/dev/null || true
            docker exec "$static_container" mkdir -p /usr/share/nginx/html/assets/pronto/menu 2>/dev/null || true

            # Copiar JS bundles
            echo "   - Copiando JS bundles..."
            docker cp "${PRONTO_STATIC_ASSETS_DIR}/js/clients/"*.js "$static_container:/usr/share/nginx/html/assets/js/" 2>/dev/null || true
            docker cp "${PRONTO_STATIC_ASSETS_DIR}/js/employees/"*.js "$static_container:/usr/share/nginx/html/assets/js/" 2>/dev/null || true

            # Copiar CSS
            echo "   - Copiando CSS..."
            docker cp "${PRONTO_STATIC_ASSETS_DIR}/css/"* "$static_container:/usr/share/nginx/html/assets/css/" 2>/dev/null || true

            # Copiar branding
            echo "   - Copiando branding..."
            docker cp "${PRONTO_STATIC_ASSETS_DIR}/pronto/branding/"* "$static_container:/usr/share/nginx/html/assets/pronto/branding/" 2>/dev/null || true

            # Copiar imágenes de menú
            echo "   - Copiando imágenes de menú..."
            docker cp "${PRONTO_STATIC_ASSETS_DIR}/pronto/menu/"* "$static_container:/usr/share/nginx/html/assets/pronto/menu/" 2>/dev/null || true

            # Recargar nginx
            docker exec "$static_container" nginx -s reload 2>/dev/null || true

            echo "   ✅ Contenido sincronizado al pod '${static_container}'"
            echo "   📍 URL: ${PRONTO_STATIC_CONTAINER_HOST:-http://localhost:9088}/"
            ;;

        Linux)
            echo ">> Sincronizando contenido estático al servidor nginx local (Linux)"
            echo "   📍 Servidor: ${nginx_host}:${nginx_port}"
            echo "   📁 Raíz: ${static_content_root}"

            # Verificar que static_content_root existe
            if [[ ! -d "${static_content_root}" ]]; then
                echo "   ⚠️  Creando directorio static_content_root..."
                sudo install -d "${static_content_root}" || true
            fi

            # Sincronizar estructura completa de assets
            echo "   - Sincronizando assets/..."
            sudo install -d "${static_content_root}/assets/js/clients" || true
            sudo install -d "${static_content_root}/assets/js/employees" || true
            sudo install -d "${static_content_root}/assets/css/clients" || true
            sudo install -d "${static_content_root}/assets/css/employees" || true
            sudo install -d "${static_content_root}/assets/pronto/branding" || true
            sudo install -d "${static_content_root}/assets/pronto/menu" || true

            # JS compilado clientes
            if [[ -d "${PRONTO_STATIC_ASSETS_DIR}/js/clients" ]]; then
                sudo rsync -a "${PRONTO_STATIC_ASSETS_DIR}/js/clients/" "${static_content_root}/assets/js/clients/"
            fi

            # JS compilado empleados
            if [[ -d "${PRONTO_STATIC_ASSETS_DIR}/js/employees" ]]; then
                sudo rsync -a "${PRONTO_STATIC_ASSETS_DIR}/js/employees/" "${static_content_root}/assets/js/employees/"
            fi

            # CSS compartido
            if [[ -d "${PRONTO_STATIC_ASSETS_DIR}/css" ]]; then
                sudo rsync -a "${PRONTO_STATIC_ASSETS_DIR}/css/" "${static_content_root}/assets/css/"
            fi

            # Branding
            if [[ -d "${PRONTO_STATIC_ASSETS_DIR}/pronto/branding" ]]; then
                sudo rsync -a "${PRONTO_STATIC_ASSETS_DIR}/pronto/branding/" "${static_content_root}/assets/pronto/branding/"
            fi

            # Imágenes de menú
            if [[ -d "${PRONTO_STATIC_ASSETS_DIR}/pronto/menu" ]]; then
                sudo rsync -a "${PRONTO_STATIC_ASSETS_DIR}/pronto/menu/" "${static_content_root}/assets/pronto/menu/"
            fi

            # JS vanilla compartido
            if [[ -d "${PRONTO_STATIC_ASSETS_DIR}/js" ]]; then
                sudo rsync -a "${PRONTO_STATIC_ASSETS_DIR}/js/" "${static_content_root}/assets/js/"
            fi

            # Corregir permisos
            sudo chmod -R a+rX "${static_content_root}/assets" 2>/dev/null || true

            # Placeholder si no existe contenido
            ensure_static_placeholder

            # Recargar nginx si está ejecutándose
            if pgrep -x nginx > /dev/null 2>&1; then
                sudo nginx -s reload 2>/dev/null || true
                echo "   ✅ Nginx recargado"
            fi

            echo "   ✅ Contenido sincronizado a ${static_content_root}"
            echo "   📍 URL: http://${nginx_host}:${nginx_port}/"
            ;;

        *)
            echo ">> Omitiendo sincronización de estáticos (sistema no reconocido: ${os_type})."
            return 0
            ;;
    esac
}
