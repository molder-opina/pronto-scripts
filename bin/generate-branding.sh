#!/usr/bin/env bash
# bin/generate-branding.sh - Genera recursos de branding con IA
# APIs soportadas: pollinations (gratis), stability, replicate
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Cargar configuración
ENV_FILE="${PROJECT_ROOT}/.env"
# shellcheck source=../.env
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"

RESTAURANT_NAME="${RESTAURANT_NAME:-Mi Restaurante}"
RESTAURANT_SLUG="${RESTAURANT_NAME:-cafeteria-test}"
OUTPUT_DIR="/var/www/pronto-static/assets/${RESTAURANT_SLUG}"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# API por defecto
API_PROVIDER="${AI_IMAGE_API:-pollinations}"

show_usage() {
    cat <<EOF
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
  🎨 Generador de Branding con IA para Pronto
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

Uso: $(basename "$0") [opciones]

${YELLOW}APIs disponibles:${NC}
  pollinations  - Gratis, sin API key (default)
  stability     - Requiere STABILITY_API_KEY
  replicate     - Requiere REPLICATE_API_TOKEN

${YELLOW}Opciones:${NC}
  -a, --api <provider>    API a usar (pollinations|stability|replicate)
  -n, --name <nombre>     Nombre del restaurante
  -s, --style <estilo>    Estilo del logo (modern|classic|minimal|playful)
  -c, --color <color>     Color principal (hex sin #, ej: FF6B35)
  -o, --output <dir>      Directorio de salida
  -h, --help              Muestra esta ayuda

${YELLOW}Ejemplos:${NC}
  $(basename "$0")                              # Genera con valores por defecto
  $(basename "$0") -a pollinations -s modern    # Usa Pollinations con estilo moderno
  $(basename "$0") -n "Café Luna" -c "8B4513"   # Nombre y color personalizados

${YELLOW}Recursos generados:${NC}
  branding/logo.png       - Logo principal (512x512)
  branding/icon.png       - Icono/favicon (128x128)
  branding/banner.png     - Banner horizontal (1200x400)
  icons/placeholder.png   - Placeholder para productos (256x256)

EOF
}

# Función para generar con Pollinations (GRATIS)
generate_pollinations() {
    local prompt="$1"
    local output="$2"
    local width="${3:-512}"
    local height="${4:-512}"

    echo -e "  ${BLUE}→${NC} Generando con Pollinations.ai..."

    # Pollinations usa URL encoding del prompt
    local encoded_prompt
    encoded_prompt=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$prompt'))")
    local url
    url="https://image.pollinations.ai/prompt/${encoded_prompt}?width=${width}&height=${height}&nologo=true"

    if curl -sL "$url" -o "$output" 2>/dev/null; then
        # Verificar que sea una imagen válida
        if file "$output" | grep -qE "(PNG|JPEG|image)"; then
            echo -e "  ${GREEN}✓${NC} Guardado: $output"
            return 0
        fi
    fi

    echo -e "  ${RED}✗${NC} Error generando imagen"
    return 1
}

# Función para generar con Stability AI
generate_stability() {
    local prompt="$1"
    local output="$2"
    local width="${3:-512}"
    local height="${4:-512}"

    if [[ -z "${STABILITY_API_KEY:-}" ]]; then
        echo -e "  ${RED}✗${NC} STABILITY_API_KEY no configurada"
        return 1
    fi

    echo -e "  ${BLUE}→${NC} Generando con Stability AI..."

    local response
    response=$(curl -s "https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image" \
        -H "Authorization: Bearer ${STABILITY_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"text_prompts\": [{\"text\": \"$prompt\"}],
            \"cfg_scale\": 7,
            \"width\": $width,
            \"height\": $height,
            \"samples\": 1,
            \"steps\": 30
        }")

    # Extraer y decodificar imagen base64
    echo "$response" | jq -r '.artifacts[0].base64' | base64 -d > "$output" 2>/dev/null

    if [[ -f "$output" ]] && file "$output" | grep -qE "(PNG|JPEG|image)"; then
        echo -e "  ${GREEN}✓${NC} Guardado: $output"
        return 0
    fi

    echo -e "  ${RED}✗${NC} Error generando imagen"
    return 1
}

# Función para generar con Replicate
generate_replicate() {
    local prompt="$1"
    local output="$2"
    local width="${3:-512}"
    local height="${4:-512}"

    if [[ -z "${REPLICATE_API_TOKEN:-}" ]]; then
        echo -e "  ${RED}✗${NC} REPLICATE_API_TOKEN no configurada"
        return 1
    fi

    echo -e "  ${BLUE}→${NC} Generando con Replicate..."

    # Crear predicción
    local prediction
    prediction=$(curl -s -X POST "https://api.replicate.com/v1/predictions" \
        -H "Authorization: Token ${REPLICATE_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"version\": \"ac732df83cea7fff18b8472768c88ad041fa750ff7682a21affe81863cbe77e4\",
            \"input\": {
                \"prompt\": \"$prompt\",
                \"width\": $width,
                \"height\": $height
            }
        }")

    local prediction_id
    prediction_id=$(echo "$prediction" | jq -r '.id')

    # Esperar resultado
    for _ in {1..60}; do
        sleep 2
        local status
        status=$(curl -s "https://api.replicate.com/v1/predictions/$prediction_id" \
            -H "Authorization: Token ${REPLICATE_API_TOKEN}")

        local state
        state=$(echo "$status" | jq -r '.status')

        if [[ "$state" == "succeeded" ]]; then
            local image_url
            image_url=$(echo "$status" | jq -r '.output[0]')
            curl -sL "$image_url" -o "$output"
            echo -e "  ${GREEN}✓${NC} Guardado: $output"
            return 0
        elif [[ "$state" == "failed" ]]; then
            break
        fi
    done

    echo -e "  ${RED}✗${NC} Error generando imagen"
    return 1
}

# Función principal de generación
generate_image() {
    local prompt="$1"
    local output="$2"
    local width="${3:-512}"
    local height="${4:-512}"

    case "$API_PROVIDER" in
        pollinations)
            generate_pollinations "$prompt" "$output" "$width" "$height"
            ;;
        stability)
            generate_stability "$prompt" "$output" "$width" "$height"
            ;;
        replicate)
            generate_replicate "$prompt" "$output" "$width" "$height"
            ;;
        *)
            echo -e "${RED}API no soportada: $API_PROVIDER${NC}"
            return 1
            ;;
    esac
}

# Parsear argumentos
STYLE="modern"
COLOR="FF6B35"

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--api) API_PROVIDER="$2"; shift 2 ;;
        -n|--name) RESTAURANT_NAME="$2"; shift 2 ;;
        -s|--style) STYLE="$2"; shift 2 ;;
        -c|--color) COLOR="$2"; shift 2 ;;
        -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help) show_usage; exit 0 ;;
        *) echo "Opción desconocida: $1"; show_usage; exit 1 ;;
    esac
done

# Crear directorios
mkdir -p "${OUTPUT_DIR}/branding" "${OUTPUT_DIR}/icons"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  🎨 ${GREEN}Generando Branding para: ${RESTAURANT_NAME}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  API: ${YELLOW}${API_PROVIDER}${NC}"
echo -e "  Estilo: ${YELLOW}${STYLE}${NC}"
echo -e "  Color: ${YELLOW}#${COLOR}${NC}"
echo -e "  Salida: ${YELLOW}${OUTPUT_DIR}${NC}"
echo ""

# Definir prompts según estilo
case "$STYLE" in
    modern)
        LOGO_STYLE="modern minimalist flat design, clean lines, geometric shapes"
        ;;
    classic)
        LOGO_STYLE="classic elegant vintage, ornate details, traditional typography"
        ;;
    minimal)
        LOGO_STYLE="ultra minimal, simple shapes, negative space, monochrome accents"
        ;;
    playful)
        LOGO_STYLE="fun playful colorful, cartoon style, friendly, vibrant"
        ;;
    *)
        LOGO_STYLE="professional modern clean"
        ;;
esac

# Generar logo principal
echo -e "${YELLOW}[1/4]${NC} Generando logo principal..."
LOGO_PROMPT="Restaurant logo for '${RESTAURANT_NAME}', ${LOGO_STYLE}, food industry, professional branding, vector style, white background, high quality, centered composition"
generate_image "$LOGO_PROMPT" "${OUTPUT_DIR}/branding/logo.png" 512 512

# Generar icono
echo ""
echo -e "${YELLOW}[2/4]${NC} Generando icono/favicon..."
ICON_PROMPT="Simple icon symbol for '${RESTAURANT_NAME}' restaurant, ${LOGO_STYLE}, single recognizable symbol, app icon style, centered, white background"
generate_image "$ICON_PROMPT" "${OUTPUT_DIR}/branding/icon.png" 128 128

# Generar banner
echo ""
echo -e "${YELLOW}[3/4]${NC} Generando banner..."
BANNER_PROMPT="Wide horizontal banner for '${RESTAURANT_NAME}' restaurant, ${LOGO_STYLE}, elegant food presentation, appetizing, professional photography style, warm lighting"
generate_image "$BANNER_PROMPT" "${OUTPUT_DIR}/branding/banner.png" 1200 400

# Generar placeholder
echo ""
echo -e "${YELLOW}[4/4]${NC} Generando placeholder para productos..."
PLACEHOLDER_PROMPT="Food placeholder image, elegant plate presentation, ${LOGO_STYLE}, appetizing, professional food photography, soft lighting, clean background"
generate_image "$PLACEHOLDER_PROMPT" "${OUTPUT_DIR}/icons/placeholder.png" 256 256

# Ajustar permisos
chmod -R 755 "${OUTPUT_DIR}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}✅ Branding generado exitosamente${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Archivos generados:"
find "${OUTPUT_DIR}/branding" "${OUTPUT_DIR}/icons" -maxdepth 1 -type f -name '*.png' -print 2>/dev/null
echo ""
echo -e "  URL base: ${YELLOW}https://pronto-static.molderx.xyz/assets/${RESTAURANT_SLUG}/${NC}"
echo ""
