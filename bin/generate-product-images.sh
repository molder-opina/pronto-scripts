#!/usr/bin/env bash
# bin/generate-product-images.sh - Genera imágenes de productos con IA
# Lee productos del seed y genera imágenes automáticamente
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Cargar configuración
ENV_FILE="${PROJECT_ROOT}/.env"
# shellcheck source=../.env
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"

RESTAURANT_SLUG="${RESTAURANT_NAME:-cafeteria-test}"
OUTPUT_DIR="/var/www/pronto-static/assets/${RESTAURANT_SLUG}/products"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# API por defecto
API_PROVIDER="${AI_IMAGE_API:-pollinations}"
DELAY_BETWEEN=3  # Segundos entre requests para no saturar API

show_usage() {
    cat <<EOF
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
  🍕 Generador de Imágenes de Productos con IA
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

Uso: $(basename "$0") [opciones]

${YELLOW}APIs disponibles:${NC}
  pollinations  - Gratis, sin API key (default)
  stability     - Requiere STABILITY_API_KEY
  replicate     - Requiere REPLICATE_API_TOKEN

${YELLOW}Opciones:${NC}
  -a, --api <provider>    API a usar (pollinations|stability|replicate)
  -c, --category <cat>    Solo generar para categoría específica
  -l, --limit <n>         Límite de productos a generar
  -d, --delay <seg>       Delay entre requests (default: 3s)
  -o, --output <dir>      Directorio de salida
  --dry-run               Solo mostrar qué se generaría
  -h, --help              Muestra esta ayuda

${YELLOW}Ejemplos:${NC}
  $(basename "$0")                          # Genera todas las imágenes
  $(basename "$0") -c "Entradas" -l 5       # Solo 5 productos de Entradas
  $(basename "$0") --dry-run                # Ver qué se generaría

EOF
}

# Función para generar con Pollinations (GRATIS)
generate_pollinations() {
    local prompt="$1"
    local output="$2"

    local encoded_prompt
    encoded_prompt=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$prompt'))")
    local url
    url="https://image.pollinations.ai/prompt/${encoded_prompt}?width=512&height=512&nologo=true"

    if curl -sL "$url" -o "$output" 2>/dev/null; then
        if file "$output" | grep -qE "(PNG|JPEG|image)"; then
            return 0
        fi
    fi
    return 1
}

# Función para generar con Stability AI
generate_stability() {
    local prompt="$1"
    local output="$2"

    if [[ -z "${STABILITY_API_KEY:-}" ]]; then
        return 1
    fi

    local response
    response=$(curl -s "https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image" \
        -H "Authorization: Bearer ${STABILITY_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"text_prompts\": [{\"text\": \"$prompt\"}],
            \"cfg_scale\": 7,
            \"width\": 512,
            \"height\": 512,
            \"samples\": 1,
            \"steps\": 30
        }")

    echo "$response" | jq -r '.artifacts[0].base64' | base64 -d > "$output" 2>/dev/null

    if [[ -f "$output" ]] && file "$output" | grep -qE "(PNG|JPEG|image)"; then
        return 0
    fi
    return 1
}

# Función principal de generación
generate_image() {
    local prompt="$1"
    local output="$2"

    case "$API_PROVIDER" in
        pollinations)
            generate_pollinations "$prompt" "$output"
            ;;
        stability)
            generate_stability "$prompt" "$output"
            ;;
        *)
            generate_pollinations "$prompt" "$output"
            ;;
    esac
}

EMPLOYEE_API_BASE="${EMPLOYEE_API_BASE_URL:-http://localhost:${EMPLOYEE_APP_HOST_PORT:-6081}}"
if [[ "$EMPLOYEE_API_BASE" == */api ]]; then
    API_BASE="${EMPLOYEE_API_BASE%/}"
else
    API_BASE="${EMPLOYEE_API_BASE%/}/api"
fi

# Obtener productos desde la API
get_products_from_api() {
    local category_filter="$1"
    local limit="$2"

    if ! command -v python3 >/dev/null 2>&1; then
        echo "python3 no está disponible" >&2
        return 1
    fi

    if ! menu_payload=$(curl -sf "${API_BASE}/menu" 2>/dev/null); then
        echo "No se pudo obtener /api/menu en ${API_BASE}" >&2
        return 1
    fi

    printf '%s' "$menu_payload" | python3 -c 'import json
import sys

data = json.load(sys.stdin)
category_filter = sys.argv[1].strip()
limit_arg = sys.argv[2].strip()
limit = int(limit_arg) if limit_arg else 0

rows = []
for category in data.get("categories") or []:
    name = category.get("name") or ""
    if category_filter and name != category_filter:
        continue
    for item in category.get("items") or []:
        rows.append(
            (
                item.get("id", ""),
                item.get("name", ""),
                item.get("description", "") or "",
                name,
            )
        )

if limit > 0:
    rows = rows[:limit]

for row in rows:
    sys.stdout.write("\t".join(str(value) for value in row) + "\n")
' "$category_filter" "$limit"
}

# Parsear argumentos
CATEGORY_FILTER=""
LIMIT=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--api) API_PROVIDER="$2"; shift 2 ;;
        -c|--category) CATEGORY_FILTER="$2"; shift 2 ;;
        -l|--limit) LIMIT="$2"; shift 2 ;;
        -d|--delay) DELAY_BETWEEN="$2"; shift 2 ;;
        -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) show_usage; exit 0 ;;
        *) echo "Opción desconocida: $1"; show_usage; exit 1 ;;
    esac
done

# Crear directorio de salida
mkdir -p "${OUTPUT_DIR}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  🍕 ${GREEN}Generador de Imágenes de Productos${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  API: ${YELLOW}${API_PROVIDER}${NC}"
echo -e "  Categoría: ${YELLOW}${CATEGORY_FILTER:-Todas}${NC}"
echo -e "  Límite: ${YELLOW}${LIMIT:-Sin límite}${NC}"
echo -e "  Salida: ${YELLOW}${OUTPUT_DIR}${NC}"
if $DRY_RUN; then
    echo -e "  Modo: ${CYAN}DRY RUN (no se generarán imágenes)${NC}"
fi
echo ""

# Obtener productos
echo -e "${YELLOW}Obteniendo productos desde la API...${NC}"
products=$(get_products_from_api "$CATEGORY_FILTER" "$LIMIT")

if [[ -z "$products" ]]; then
    echo -e "${RED}No se encontraron productos${NC}"
    exit 1
fi

# Contar productos
total=$(echo "$products" | wc -l)
echo -e "Productos encontrados: ${GREEN}$total${NC}"
echo ""

# Procesar cada producto
count=0
success=0
failed=0

while IFS=$'\t' read -r id name description category; do
    ((count++))

    # Limpiar nombre para archivo
    filename=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/__*/_/g')
    output_file="${OUTPUT_DIR}/${id}_${filename}.png"

    echo -e "${CYAN}[${count}/${total}]${NC} ${name}"
    echo -e "  Categoría: ${category:-Sin categoría}"

    if $DRY_RUN; then
        echo -e "  ${YELLOW}→ Se generaría: ${output_file}${NC}"
        echo ""
        continue
    fi

    # Verificar si ya existe
    if [[ -f "$output_file" ]]; then
        echo -e "  ${YELLOW}→ Ya existe, saltando${NC}"
        echo ""
        continue
    fi

    # Crear prompt basado en categoría
    case "${category,,}" in
        *entrada*|*appetizer*)
            style="appetizer starter dish"
            ;;
        *principal*|*main*|*plato*)
            style="main course dish"
            ;;
        *postre*|*dessert*)
            style="dessert sweet dish"
            ;;
        *bebida*|*drink*|*beverage*)
            style="beverage drink glass"
            ;;
        *ensalada*|*salad*)
            style="fresh salad bowl"
            ;;
        *sopa*|*soup*)
            style="soup bowl hot"
            ;;
        *pizza*)
            style="pizza italian"
            ;;
        *hamburguesa*|*burger*)
            style="burger sandwich"
            ;;
        *taco*|*mexican*)
            style="mexican food taco"
            ;;
        *)
            style="restaurant dish"
            ;;
    esac

    # Construir prompt
    prompt="Professional food photography of ${name}, ${style}, ${description:-appetizing presentation}, on elegant plate, restaurant quality, soft lighting, shallow depth of field, high resolution, appetizing, delicious looking"

    echo -e "  ${BLUE}→ Generando imagen...${NC}"

    if generate_image "$prompt" "$output_file"; then
        echo -e "  ${GREEN}✓ Guardado: ${output_file}${NC}"
        ((success++))
    else
        echo -e "  ${RED}✗ Error generando imagen${NC}"
        ((failed++))
    fi

    echo ""

    # Delay entre requests
    if [[ $count -lt $total ]]; then
        sleep "$DELAY_BETWEEN"
    fi

done <<< "$products"

# Ajustar permisos
chmod -R 755 "${OUTPUT_DIR}" 2>/dev/null || true

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if $DRY_RUN; then
    echo -e "  ${CYAN}DRY RUN completado${NC}"
    echo -e "  Productos que se procesarían: $total"
else
    echo -e "  ${GREEN}✅ Generación completada${NC}"
    echo -e "  Exitosos: ${GREEN}$success${NC}"
    echo -e "  Fallidos: ${RED}$failed${NC}"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Directorio: ${YELLOW}${OUTPUT_DIR}${NC}"
echo -e "  URL base: ${YELLOW}https://pronto-static.molderx.xyz/assets/${RESTAURANT_SLUG}/products/${NC}"
echo ""
